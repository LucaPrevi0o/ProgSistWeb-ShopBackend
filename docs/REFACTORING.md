# Refactoring Plan

This document describes the planned refactoring process for the Rails back-end and the Angular front-end.

The source of truth for the target API shape is:

```txt
docs/API_CONTRACT.md
```

The API contract defines:

- Angular-facing DTOs and JSON shapes;
- Rails/database model responsibilities;
- request and response wrappers;
- naming rules between `camelCase` and `snake_case`;
- known mismatches to fix.

The goal of this refactor is not only to make the code cleaner, but to establish a stable separation of concerns:

| Layer | Responsibility |
|---|---|
| Angular components/services | Work with DTOs using `camelCase` |
| HTTP JSON boundary | Send and receive `camelCase` JSON |
| Rails controllers | Authenticate, authorize, normalize input, call services, serialize output |
| Rails services | Execute business logic using `snake_case` data |
| Rails models/database | Persist normalized domain data using Rails conventions |
| Serializers | Convert Rails/domain objects into Angular DTO-shaped JSON |

---

## 0. Guiding rules

Before changing code, every phase must respect the following rules from `docs/API_CONTRACT.md`.

### 0.1 Naming boundary

Angular and HTTP JSON use `camelCase`.

Rails models, database columns, service objects, and internal params use `snake_case`.

Conversion must happen only at the API boundary:

```txt
incoming HTTP JSON -> request normalization -> Rails services/models
Rails models/services -> serializers -> outgoing HTTP JSON
```

### 0.2 DTOs are not database models

Angular DTOs describe what the front-end consumes.

Rails models describe how data is stored and related.

They may have similar names, but they are not the same object. The bridge between them is made by:

- request normalization;
- service-layer input objects;
- serializers.

### 0.3 `PaymentMethod.details` is an exception

`PaymentMethod.details` is intentionally treated as opaque JSON.

Its keys should remain Angular-shaped, for example:

```json
{
  "cardNumber": "4111111111111111",
  "expiryMonth": 12,
  "expiryYear": 2030,
  "cvv": "123",
  "cardHolderName": "Mario Rossi"
}
```

It must not be blindly converted to:

```json
{
  "card_number": "...",
  "expiry_month": 12
}
```

This exception is explicitly described in `docs/API_CONTRACT.md`.

---

## 1. Phase 1 — Align the database schema with the target domain model

### Objective

Make the Rails database capable of representing the target model relations described in Section 2 of `docs/API_CONTRACT.md`.

This phase should happen before controller cleanup, because controllers and serializers need a stable model layer.

---

### 1.1 Add or verify `users.role`

#### Current problem

The application expects users to have a role, especially for admin authorization.

The API contract defines:

```txt
User -> users table:
id, email, password_digest, user_info, role, created_at, updated_at
```

#### Target

The `users` table must include:

```ruby
role :string
```

with a default value:

```ruby
"USER"
```

#### Suggested migration

```ruby
class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: "USER"
    add_index :users, :role
  end
end
```

#### Acceptance criteria

- New users are created with role `"USER"`.
- Admin users can be represented with role `"ADMIN"`.
- `User#admin?` works consistently.
- Angular can rely on `user.role`.

---

### 1.2 Decide the final structure of `UserInfo`, `PersonalData`, and `Address`

#### Target from API contract

The target relation is:

```txt
User
  has_one UserInfo

UserInfo
  belongs_to User
  has_one PersonalData
  has_many PaymentMethod

PersonalData
  belongs_to UserInfo
  has_one Address

Address
  belongs_to PersonalData
```

Angular still sees:

```json
{
  "userInfo": {
    "data": {
      "firstName": "Mario",
      "lastName": "Rossi",
      "phone": "3331234567",
      "address": {
        "street": "Via Roma 1",
        "city": "Ferrara",
        "postalCode": "44121",
        "country": "Italy"
      }
    },
    "paymentMethods": []
  }
}
```

Rails should store this through normalized models.

#### Required tables

```txt
user_infos
personal_data
addresses
payment_methods
```

#### Refactoring direction

If `user_infos.data` currently stores profile data as JSON, migrate toward a structured `personal_data` table.

If profile address is currently embedded, migrate toward an `addresses` table.

#### Acceptance criteria

- `UserInfo#data` can return the associated `PersonalData` object or a serializer-compatible representation.
- `PersonalData` has one `Address`.
- Angular still receives `userInfo.data.address.postalCode`.
- Rails internally uses `postal_code`.

---

### 1.3 Decide how orders store snapshots

#### Target from API contract

An `Order` contains:

```json
{
  "id": 1,
  "userId": 1,
  "items": [],
  "personalData": {},
  "paymentMethod": {},
  "createdAt": "..."
}
```

Important rule:

```txt
personalData and paymentMethod are required order snapshots.
```

They are not simply references to the current user profile, because the user may edit their profile later.

#### Required decision

Order data can be stored in one of two ways.

##### Option A — Snapshot JSON columns

Keep:

```txt
orders.personal_data
orders.payment_method
orders.items
```

as immutable JSON snapshots.

This is simpler for a university project and matches checkout behavior well.

##### Option B — Fully relational order records

Use relational tables such as:

```txt
orders
order_items
order_personal_data
order_addresses
order_payment_methods
```

This is cleaner for complex querying, but heavier.

#### Recommended target

Use a mixed approach:

| Data | Recommended storage |
|---|---|
| Order identity, user, status, total | relational columns |
| Order items | `order_items` relational table |
| Checkout personal data | snapshot JSON in `orders.personal_data` |
| Checkout payment method | snapshot JSON in `orders.payment_method` |

This keeps product/order item logic relational while preserving the historical checkout data.

#### Acceptance criteria

- Editing user profile later does not change old orders.
- Editing payment methods later does not change old orders.
- Order serialization still returns `personalData` and `paymentMethod`.
- `paymentMethod.details` remains camelCase.

---

### 1.4 Review `payment_methods.type`

> **NOTE**: This problem has been addressed in the `docs/API_CONTRACT.md` file by updating the DTO and model description. This column will be renamed as `method_type` for the Rails back-end database model, as well as `methodType` for the Angular DTO, for consistency.

#### Current problem

Rails treats a column named `type` as the Single Table Inheritance column by default.

#### Target

Either rename the column:

```txt
type -> method_type
```

or explicitly disable STI in the model:

```ruby
self.inheritance_column = :_type_disabled
```

#### Recommendation

For a clean refactor, prefer renaming the column to:

```txt
method_type
```

but keep the API field as:

```json
{
  "type": "creditCard"
}
```

The serializer maps:

```txt
method_type -> type
```

The request normalizer maps:

```txt
type -> method_type
```

#### Acceptance criteria

- Rails no longer treats payment methods as STI records.
- Angular still sends and receives `type`.
- Database uses a Rails-safe column name.

---

## 2. Phase 2 — Add request normalization

### Objective

Create one centralized mechanism that converts incoming Angular JSON into Rails-friendly params.

This phase directly implements Section 7 of `docs/API_CONTRACT.md`.

---

### 2.1 Create a key transformation utility

Suggested file:

```txt
app/lib/api_key_transform.rb
```

Target responsibilities:

```ruby
ApiKeyTransform.underscore_keys(value)
ApiKeyTransform.camelize_keys(value)
```

The utility should handle:

- hashes;
- arrays;
- nested structures;
- scalar values.

---

### 2.2 Preserve opaque JSON paths

The transformer must support exceptions.

At minimum, this path must not be deep-converted:

```txt
paymentMethod.details
paymentMethods[].details
payment_method.details
payment_methods[].details
```

Example:

```json
{
  "paymentMethod": {
    "type": "creditCard",
    "details": {
      "cardNumber": "4111111111111111",
      "cardHolderName": "Mario Rossi"
    }
  }
}
```

should become:

```json
{
  "payment_method": {
    "type": "creditCard",
    "details": {
      "cardNumber": "4111111111111111",
      "cardHolderName": "Mario Rossi"
    }
  }
}
```

not:

```json
{
  "payment_method": {
    "type": "creditCard",
    "details": {
      "card_number": "4111111111111111",
      "card_holder_name": "Mario Rossi"
    }
  }
}
```

---

### 2.3 Add controller concern for normalized params

Suggested file:

```txt
app/controllers/concerns/api_request_params.rb
```

Target behavior:

```ruby
normalized_json_body
normalized_resource(:user_info)
normalized_resource(:cart_item)
normalized_resource(:order)
```

Example usage:

```ruby
def create
  order_params = normalized_resource(:order)
  order = Orders::Create.call(current_user:, params: order_params)

  render json: { orderId: order.id }, status: :created
end
```

#### Acceptance criteria

- Controllers no longer manually check both `personalData` and `personal_data`.
- Controllers no longer manually check both `paymentMethod` and `payment_method`.
- Controllers no longer manually check both `productId` and `product_id`.
- `PaymentMethod.details` remains camelCase.

---

## 3. Phase 3 — Add serializers

### Objective

Create explicit serializers that convert Rails/domain objects into Angular DTOs.

This phase implements Sections 2 and 6 of `docs/API_CONTRACT.md`.

---

### 3.1 Serializer list

Suggested files:

```txt
app/serializers/product_serializer.rb
app/serializers/cart_serializer.rb
app/serializers/cart_item_serializer.rb
app/serializers/order_serializer.rb
app/serializers/user_serializer.rb
app/serializers/user_info_serializer.rb
app/serializers/personal_data_serializer.rb
app/serializers/address_serializer.rb
app/serializers/payment_method_serializer.rb
```

Optional admin-specific serializers:

```txt
app/serializers/admin/product_serializer.rb
app/serializers/admin/order_serializer.rb
app/serializers/admin/user_serializer.rb
```

---

### 3.2 Serializer rule

Serializers should not simply expose every model column.

They should explicitly select the API fields.

Example:

```ruby
class ProductSerializer
  def self.call(product)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      category: product.category,
      price: product.price,
      stock: product.stock
    }
  end
end
```

For nested objects:

```ruby
class UserSerializer
  def self.call(user, include_token: nil)
    payload = {
      id: user.id,
      email: user.email,
      role: user.role,
      user_info: UserInfoSerializer.call(user.user_info)
    }

    payload[:token] = include_token if include_token

    ApiKeyTransform.camelize_keys(payload)
  end
end
```

---

### 3.3 Payment method serializer exception

The payment method serializer must preserve `details` as-is.

Example:

```ruby
class PaymentMethodSerializer
  def self.call(payment_method)
    {
      id: payment_method.id,
      type: payment_method.method_type,
      details: payment_method.details
    }
  end
end
```

Then camelize only the Rails-backed keys, not the internals of `details`.

#### Acceptance criteria

- `UserSerializer` returns `userInfo`, not `user_info`.
- `PersonalDataSerializer` returns `firstName`, not `first_name`.
- `AddressSerializer` returns `postalCode`, not `postal_code`.
- `PaymentMethodSerializer` returns `details.cardHolderName`, not `details.card_holder_name`.
- `password_digest` is never serialized.

---

## 4. Phase 4 — Refactor authentication and user profile endpoints

### Objective

Make user-related endpoints match Section 3.1 of `docs/API_CONTRACT.md`.

---

### 4.1 Authentication endpoints

Target endpoints:

```txt
POST /login
POST /users
```

Target response:

```json
{
  "id": 1,
  "email": "user@example.com",
  "token": "...",
  "role": "USER",
  "userInfo": null
}
```

or:

```json
{
  "id": 1,
  "email": "user@example.com",
  "token": "...",
  "role": "USER",
  "userInfo": {
    "data": null,
    "paymentMethods": []
  }
}
```

#### Refactoring tasks

- Use `UserSerializer`.
- Make token inclusion explicit.
- Ensure role exists.
- Do not expose `password_digest`.
- Ensure every new user has a cart if the app expects it.

---

### 4.2 User profile endpoint

Target endpoint:

```txt
GET /users/:id
```

Target response:

```json
{
  "id": 1,
  "email": "user@example.com",
  "role": "USER",
  "userInfo": {
    "data": {
      "firstName": "Mario",
      "lastName": "Rossi",
      "phone": "3331234567",
      "address": {
        "street": "Via Roma 1",
        "city": "Ferrara",
        "postalCode": "44121",
        "country": "Italy"
      }
    },
    "paymentMethods": []
  }
}
```

#### Refactoring tasks

- Replace manual JSON construction with `UserSerializer`.
- Replace `info` wrapper with `userInfo`.
- Keep temporary compatibility if the current Angular code still expects `info`.

---

### 4.3 User info update endpoint

Target endpoint:

```txt
PATCH /users/:id/user-info
```

Target request:

```json
{
  "userInfo": {
    "data": {
      "firstName": "Mario",
      "lastName": "Rossi",
      "phone": "3331234567",
      "address": {
        "street": "Via Roma 1",
        "city": "Ferrara",
        "postalCode": "44121",
        "country": "Italy"
      }
    },
    "paymentMethods": []
  }
}
```

#### Refactoring tasks

- Normalize `userInfo` to `user_info`.
- Extract business logic into a service:

```txt
Users::UpsertUserInfo
```

- Update or create:
  - `UserInfo`;
  - `PersonalData`;
  - `Address`;
  - `PaymentMethod` records.

#### Acceptance criteria

- Controller does not manually build nested personal data.
- Controller delegates persistence to a service.
- Response uses `UserSerializer`.

---

## 5. Phase 5 — Refactor product endpoints

### Objective

Make product endpoints match Section 3.2 of `docs/API_CONTRACT.md`.

---

### 5.1 Public product endpoints

Target endpoints:

```txt
GET /products
GET /products/:id
GET /categories
```

Target list query params:

```txt
name
category
minPrice
maxPrice
page
```

Rails internal params:

```txt
name
category
min_price
max_price
page
```

#### Refactoring tasks

- Normalize query params if Angular is changed to `minPrice` / `maxPrice`.
- Keep temporary support for `min_price` / `max_price`.
- Use `ProductSerializer`.
- Keep public product response compact.

---

### 5.2 Admin product endpoints

Target endpoints:

```txt
GET /admin/products
GET /admin/products/:id
POST /admin/products
PATCH /admin/products/:id
DELETE /admin/products/:id
```

#### Refactoring tasks

- Use admin authorization.
- Use serializers.
- Decide whether admin product responses include `createdAt` and `updatedAt`.
- Keep request payload as:

```json
{
  "product": {
    "name": "Keyboard",
    "description": "Mechanical keyboard",
    "category": "Electronics",
    "price": 49.99,
    "stock": 10
  }
}
```

#### Acceptance criteria

- Public product responses and admin product responses are intentionally different only if needed.
- No controller manually formats product JSON.

---

## 6. Phase 6 — Refactor cart endpoints

### Objective

Make cart endpoints match Section 3.3 of `docs/API_CONTRACT.md`.

---

### 6.1 Target endpoints

```txt
POST /cart
GET /cart
POST /cart/items
PATCH /cart/items/:productId
DELETE /cart/items/:productId
DELETE /cart
```

---

### 6.2 Target cart item request

```json
{
  "cartItem": {
    "productId": 1,
    "quantity": 2
  }
}
```

Rails internal params:

```json
{
  "cart_item": {
    "product_id": 1,
    "quantity": 2
  }
}
```

---

### 6.3 Service objects

Suggested services:

```txt
Carts::FindOrCreate
Carts::AddItem
Carts::UpdateItem
Carts::RemoveItem
Carts::Clear
```

Responsibilities:

| Service | Responsibility |
|---|---|
| `Carts::FindOrCreate` | Return the authenticated user's cart, creating it if missing |
| `Carts::AddItem` | Validate product, stock, quantity, add or increment cart item |
| `Carts::UpdateItem` | Change quantity, remove if zero if desired |
| `Carts::RemoveItem` | Remove product from cart |
| `Carts::Clear` | Remove all cart items |

---

### 6.4 Serialization

Use:

```txt
CartSerializer
CartItemSerializer
ProductSerializer
```

Target response:

```json
{
  "id": 1,
  "user": {
    "id": 1,
    "email": "user@example.com",
    "role": "USER",
    "userInfo": null
  },
  "items": [
    {
      "product": {
        "id": 1,
        "name": "Keyboard",
        "description": "Mechanical keyboard",
        "category": "Electronics",
        "price": 49.99,
        "stock": 10
      },
      "quantity": 2
    }
  ]
}
```

#### Acceptance criteria

- Cart controller has minimal logic.
- Stock validation lives outside the controller.
- Cart JSON is produced by serializers.
- Temporary support for old `cart_item.product_id` can remain during migration.

---

## 7. Phase 7 — Refactor checkout and orders

### Objective

Make checkout and order endpoints match Section 3.4 of `docs/API_CONTRACT.md`.

---

### 7.1 Checkout endpoint

Target endpoint:

```txt
POST /checkout
```

Target request:

```json
{
  "order": {
    "items": [
      {
        "product": {
          "id": 1
        },
        "quantity": 2
      }
    ],
    "personalData": {
      "firstName": "Mario",
      "lastName": "Rossi",
      "phone": "3331234567",
      "address": {
        "street": "Via Roma 1",
        "city": "Ferrara",
        "postalCode": "44121",
        "country": "Italy"
      }
    },
    "paymentMethod": {
      "type": "payPal",
      "details": {
        "email": "user@example.com"
      }
    }
  }
}
```

Rails internal params:

```json
{
  "order": {
    "items": [
      {
        "product": {
          "id": 1
        },
        "quantity": 2
      }
    ],
    "personal_data": {
      "first_name": "Mario",
      "last_name": "Rossi",
      "phone": "3331234567",
      "address": {
        "street": "Via Roma 1",
        "city": "Ferrara",
        "postal_code": "44121",
        "country": "Italy"
      }
    },
    "payment_method": {
      "type": "payPal",
      "details": {
        "email": "user@example.com"
      }
    }
  }
}
```

Target response:

```json
{
  "orderId": 1
}
```

---

### 7.2 Checkout service

Suggested service:

```txt
Orders::Create
```

Responsibilities:

1. Use `current_user`, not request-provided `userId`.
2. Validate all products exist.
3. Validate requested quantities.
4. Validate stock.
5. Create `Order`.
6. Create `OrderItem` records or snapshot items according to the chosen storage strategy.
7. Decrement stock transactionally.
8. Store immutable `personal_data` snapshot.
9. Store immutable `payment_method` snapshot.
10. Clear the user's cart after successful checkout, if that is the intended UX.

---

### 7.3 Order list/detail endpoints

Target endpoints:

```txt
GET /orders
GET /orders/:id
```

Rules:

- A normal user can only see their own orders.
- Admin users use `/admin/orders`.
- Responses use `OrderSerializer`.

Target response:

```json
{
  "id": 1,
  "userId": 1,
  "items": [
    {
      "product": {
        "id": 1,
        "name": "Keyboard",
        "description": "Mechanical keyboard",
        "category": "Electronics",
        "price": 49.99,
        "stock": 8
      },
      "quantity": 2
    }
  ],
  "personalData": {
    "firstName": "Mario",
    "lastName": "Rossi",
    "phone": "3331234567",
    "address": {
      "street": "Via Roma 1",
      "city": "Ferrara",
      "postalCode": "44121",
      "country": "Italy"
    }
  },
  "paymentMethod": {
    "type": "payPal",
    "details": {
      "email": "user@example.com"
    }
  },
  "createdAt": "2026-06-10T12:00:00Z"
}
```

#### Acceptance criteria

- Checkout controller is small.
- Order creation is transactional.
- `orderId` response is camelCase.
- `paymentMethod.details` remains camelCase.
- Old orders remain stable even if user profile changes.

---

## 8. Phase 8 — Refactor admin endpoints

### Objective

Make admin endpoints match Section 3.5 of `docs/API_CONTRACT.md`.

---

### 8.1 Admin authorization

All `/admin/*` endpoints must require:

```txt
current_user.role == "ADMIN"
```

or equivalent:

```ruby
current_user.admin?
```

If unauthorized, return a consistent error response.

---

### 8.2 Admin users

Target endpoints:

```txt
GET /admin/users
GET /admin/users/:id
PATCH /admin/users/:id/role
```

Target serializer:

```txt
Admin::UserSerializer
```

or reuse `UserSerializer` with admin options.

Admin user responses may include:

```json
{
  "id": 1,
  "email": "user@example.com",
  "role": "USER",
  "userInfo": {},
  "createdAt": "2026-06-10T12:00:00Z",
  "updatedAt": "2026-06-11T12:00:00Z"
}
```

---

### 8.3 Admin orders

Target endpoints:

```txt
GET /admin/orders
GET /admin/orders/:id
```

The API contract currently defines `Order` with:

```txt
userId
```

If admin views need user email, define a separate DTO later, for example:

```txt
AdminOrder
```

Do not silently add extra fields to `Order` unless the contract is updated.

---

### 8.4 Admin products

Already covered in Phase 5, but admin-specific metadata can be added if documented.

#### Acceptance criteria

- Admin endpoints use consistent authorization.
- Admin JSON responses are either normal DTOs or documented admin DTOs.
- No admin endpoint exposes sensitive user fields.

---

## 9. Phase 9 — Standardize error responses

### Objective

Make error JSON predictable for Angular.

---

### 9.1 Target error shape

Use a consistent shape:

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found",
    "details": {}
  }
}
```

Suggested codes:

```txt
unauthorized
forbidden
not_found
validation_failed
out_of_stock
invalid_credentials
internal_server_error
```

---

### 9.2 Controller-level handling

Centralize common errors in:

```txt
ApplicationController
Admin::BaseController
```

Examples:

```ruby
rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed
```

---

### 9.3 Service-level errors

Service objects can raise domain-specific errors:

```txt
CartErrors::OutOfStock
OrderErrors::InvalidCheckout
AuthErrors::InvalidCredentials
```

Controllers translate these into HTTP responses.

#### Acceptance criteria

- Angular can display errors consistently.
- Controllers do not manually invent different error shapes.
- Validation errors include useful `details`.

---

## 10. Phase 10 — Update Angular DTOs and services

### Objective

Align Angular code with the final API contract while preserving the current Observable-based style.

---

### 10.1 Preserve Angular async style

Do not introduce manual subscriptions unless strictly necessary.

Keep the current style based on:

- `Observable`;
- `AsyncPipe`;
- `switchMap`;
- helper state wrappers such as `HttpState`.

---

### 10.2 DTO updates

Update Angular DTOs to match `docs/API_CONTRACT.md`.

Expected changes may include:

| Current | Target |
|---|---|
| `info` | `userInfo` |
| `min_price` | `minPrice` |
| `max_price` | `maxPrice` |
| `in_stock` | `inStock`, if kept |
| `product_id` in request bodies | `productId` |
| `order_id` response | `orderId` |
| `cardholderName` or `cardHolderName` inconsistency | `cardHolderName` |

---

### 10.3 Checkout service

If checkout response becomes:

```json
{
  "orderId": 1
}
```

then Angular should use a dedicated DTO:

```ts
export interface CheckoutResponse {
  orderId: number;
}
```

instead of typing checkout as returning a full `Order`.

---

### 10.4 User service

Update user service methods to use:

```txt
userInfo
paymentMethods
paymentMethodId
```

instead of older wrappers such as:

```txt
info
payment_methods
```

unless temporary compatibility is still needed.

---

### 10.5 Product filters

Update product filters to:

```ts
export interface ProductFilters {
  name?: string;
  category?: string;
  minPrice?: number;
  maxPrice?: number;
  inStock?: boolean;
}
```

Rails will normalize these query params to:

```txt
min_price
max_price
in_stock
```

#### Acceptance criteria

- Angular DTOs match Section 2 of `docs/API_CONTRACT.md`.
- Angular service request bodies match Section 3.
- No broad manual subscription refactor is introduced.
- Front-end behavior remains unchanged.

---

## 11. Phase 11 — Add tests around the contract

### Objective

Protect the API contract from accidental regressions.

---

### 11.1 Request specs

Add Rails request specs for:

```txt
POST /login
POST /users
GET /users/:id
PATCH /users/:id/user-info
GET /products
GET /products/:id
GET /cart
POST /cart/items
PATCH /cart/items/:productId
DELETE /cart/items/:productId
POST /checkout
GET /orders
GET /orders/:id
GET /admin/users
GET /admin/orders
GET /admin/products
```

---

### 11.2 Serializer specs

Add specs for:

```txt
ProductSerializer
UserSerializer
UserInfoSerializer
PersonalDataSerializer
AddressSerializer
PaymentMethodSerializer
CartSerializer
OrderSerializer
```

Important expectations:

```txt
first_name -> firstName
postal_code -> postalCode
user_info -> userInfo
order_id -> orderId
```

and:

```txt
details.cardHolderName stays details.cardHolderName
```

---

### 11.3 Service specs

Add specs for:

```txt
Users::UpsertUserInfo
Carts::AddItem
Carts::UpdateItem
Carts::RemoveItem
Orders::Create
```

#### Acceptance criteria

- API response shape is tested.
- Request normalization is tested.
- Payment method details exception is tested.
- Checkout transaction behavior is tested.

---

## 12. Suggested implementation order

The safest order is:

1. Add schema migrations.
2. Add key transformation utility.
3. Add serializers.
4. Add request normalization concern.
5. Refactor authentication responses.
6. Refactor user profile endpoints.
7. Refactor product endpoints.
8. Refactor cart endpoints.
9. Refactor checkout/order logic.
10. Refactor admin endpoints.
11. Update Angular DTOs/services.
12. Add or update tests.
13. Remove temporary compatibility paths.

---

## 13. Temporary compatibility strategy

During the refactor, the back-end may accept both old and new request shapes.

Examples:

| Old accepted shape | New target shape |
|---|---|
| `info` | `userInfo` |
| `cart_item.product_id` | `cartItem.productId` |
| `min_price` | `minPrice` |
| `order_id` | `orderId` |

However, responses should move to the new contract as early as possible.

Once Angular has been updated, remove old compatibility paths.

---

## 14. Final target architecture

At the end of the refactor, the typical request flow should be:

```txt
Angular component
  -> Angular service
  -> camelCase HTTP JSON
  -> Rails controller
  -> request normalization
  -> service object
  -> Rails models/database
  -> serializer
  -> camelCase HTTP JSON
  -> Angular DTO
```

A controller should look conceptually like this:

```ruby
class OrdersController < ApplicationController
  def create
    order = Orders::Create.call(
      current_user: current_user,
      params: normalized_resource(:order)
    )

    render json: { orderId: order.id }, status: :created
  end

  def index
    orders = current_user.orders.includes(:order_items, :products)

    render json: orders.map { |order| OrderSerializer.call(order) }
  end
end
```

The controller should not:

- manually convert `camelCase` and `snake_case`;
- manually build large nested JSON hashes;
- contain checkout business logic;
- trust `userId` from the request body;
- expose database-only fields.

---

## 15. Definition of done

The refactor is complete when:

- `docs/API_CONTRACT.md` matches the implemented API;
- Angular DTOs match the documented JSON shapes;
- Rails models use conventional `snake_case`;
- Rails controllers are thin;
- business logic lives in service objects;
- serializers own response JSON;
- request normalization owns inbound key conversion;
- `PaymentMethod.details` remains camelCase;
- admin authorization depends on a real `users.role` field;
- checkout returns `orderId` or another documented response;
- temporary compatibility paths have been removed or explicitly documented.