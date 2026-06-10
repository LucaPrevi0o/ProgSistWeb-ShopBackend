# API Contract

This document fixes the JSON contract expected by the Angular front-end and maps each API-facing object to the current Ruby/Rails database schema.

The rule for the refactoring is:

- Angular-facing JSON uses `camelCase`.
- Rails models, database columns, services, and internal params use `snake_case`.
- Conversion between the two formats must happen only at the API boundary:
  - request parsing: `camelCase` JSON -> `snake_case` Rails params
  - response serialization: Rails model/data -> `camelCase` JSON
- JSON objects stored as opaque JSON payloads, such as `PaymentMethod.details`, can intentionally keep their Angular-friendly `camelCase` structure.

---

## 1. Naming convention

| Layer | Naming convention | Example |
|---|---|---|
| Angular DTOs | `camelCase` | `personalData`, `paymentMethod`, `postalCode`, `createdAt` |
| HTTP request JSON | `camelCase` | `{ "order": { "personalData": ... } }` |
| HTTP response JSON | `camelCase` | `{ "userId": 1, "createdAt": "..." }` |
| Rails models | `snake_case` | `personal_data`, `payment_method`, `postal_code`, `created_at` |
| Database columns | `snake_case` | `user_id`, `created_at`, `postal_code` |
| Opaque JSON payloads | `camelCase`, when deliberately shared with Angular | `cardNumber`, `expiryMonth`, `cardHolderName` |

---

## 2. Domain JSON objects

| Angular type | Angular JSON shape | Rails model / schema mapping | Refactoring notes |
|---|---|---|---|
| `User` | ```{ "id": int, "email": string, "password": string, "token": string, "role": string, "userInfo": UserInfo }``` | `User` model -> `users` table: `id`, `email`, `password_digest`, `user_info`, `role`, `created_at`, `updated_at`. | `password` is request-only and must never be serialized. `password_digest` must never be serialized. `token` is response-only for authentication endpoints. `created_at` and `updated_at` should not be returned unless necessary, for example in admin views. |
| `UserInfo` | ```{ "data?": PersonalData, "paymentMethods?": PaymentMethod[] }``` | `UserInfo` model -> `user_infos` table: `id`, `user_id`, `data`, `payment_methods`, `created_at`, `updated_at`. | `data` and `paymentMethods` are optional fields: they can be `null`, and are not strictly required to have a set value. In the refactored target model, `data` should represent the associated `PersonalData` record, while `paymentMethods` should represent the associated `PaymentMethod` records. |
| `PersonalData` | ```{ "firstName": string, "lastName": string, "phone": string, "address": Address }``` | `PersonalData` model -> `personal_data` table: `id`, `user_info_id`, `first_name`, `last_name`, `phone`, `address`, `created_at`, `updated_at`. | `PersonalData` is the structured profile data connected to `UserInfo`. In Rails, it should use `snake_case`; in Angular, it is serialized as `camelCase`. |
| `Address` | ```{ "street": string, "city": string, "postalCode": string, "country": string }``` | `Address` model -> `addresses` table: `id`, `personal_data_id`, `street`, `city`, `postal_code`, `country`, `created_at`, `updated_at`. | `postalCode` is the Angular/API name; `postal_code` is the Rails/database name. |
| `PaymentMethod<T = CreditCard \| PayPal>` | ```{ "methodType": string, "details": T }``` | `PaymentMethod` model -> `payment_methods` table: `id`, `user_info_id`, `method_type`, `details`, `created_at`, `updated_at`. | `details` is an opaque JSON column. Its internal structure depends on `method_type`. Because `CreditCard` and `PayPal` are not Rails-backed tables, `details` can intentionally remain in Angular-friendly `camelCase`. |
| `CreditCard` | ```{ "cardNumber": string, "expiryMonth": int, "expiryYear": int, "cvv": string, "cardHolderName": string }``` | Stored inside `payment_methods.details` as regular JSON. | As this model is not stored in a table, it does not need to be manually converted between `snake_case` and `camelCase`. It should be treated as an opaque Angular-shaped JSON payload. |
| `PayPal` | ```{ "email": "user@example.com" }``` | Stored inside `payment_methods.details` as regular JSON. | As this model is not stored in a table, it does not need to be manually converted between `snake_case` and `camelCase`. |
| `Product` | ```{ "id": int, "name": string, "description": string, "category": string, "price": float, "stock": int }``` | `Product` model -> `products` table: `id`, `name`, `description`, `category`, `price`, `stock`, `created_at`, `updated_at`. | `created_at` and `updated_at` should not be returned in normal product responses unless necessary, for example in the admin product dashboard. |
| `Cart` | ```{ "id": int, "user": User, "items": CartItem[] }``` | `Cart` model -> `carts` table: `id`, `user_id`, `items`, `created_at`, `updated_at`. | `items` should be serialized from the related `cart_items` records. Returning the full nested `user` is allowed by the Angular DTO, but can be simplified later if the front-end only needs `userId`. |
| `CartItem` | ```{ "product": Product, "quantity": int }``` | `CartItem` model -> `cart_items` table: `id`, `cart_id`, `product_id`, `quantity`, `created_at`, `updated_at`. | API responses should expose the nested `product` object and `quantity`. Internal IDs such as `cart_id` and `product_id` do not need to be exposed unless the front-end needs them. |
| `Order` | ```{ "id": int, "userId": int, "items": CartItem[], "personalData": PersonalData, "paymentMethod": PaymentMethod, "createdAt": string }``` | `Order` model -> `orders` table: `id`, `user_id`, `items`, `personal_data`, `payment_method`, `created_at`, `updated_at`. | `personalData` and `paymentMethod` are required order snapshots. They are not simply references to the current `UserInfo`, because the user may later edit their profile/payment methods. `updated_at` should not be returned unless necessary. |

---

## 3. Request and response wrappers

These are not full domain models, but they are part of the HTTP contract used by Angular services.

The target convention is:

- request/response JSON uses the Angular DTO names from Section 2;
- Rails receives normalized `snake_case` params internally;
- `PaymentMethod.details` is treated as an opaque JSON payload and should not be deep-converted to `snake_case`.

### 3.1 Authentication and user profile endpoints

| Use case | Endpoint | Angular request body / params | Expected Rails internal params | Expected response | Notes |
|---|---|---|---|---|---|
| Login | `POST /login` | ```{ "email": "user@example.com", "password": "secret" }``` | `email`, `password` | `User` with `id`, `email`, `token`, `role`, optional `userInfo` | `password` is request-only. `password_digest` must never be returned. |
| Register | `POST /users` | ```{ "email": "user@example.com", "password": "secret" }``` | `email`, `password` | `User` with `id`, `email`, `token`, `role`, optional `userInfo` | New users should receive a default role, normally `"USER"`. |
| Get user profile | `GET /users/:id` | none | `params[:id]` | `User` with nested `userInfo` | `userInfo.data` and `userInfo.paymentMethods` may be `null` or empty. |
| Create or update user info | `PATCH /users/:id/user-info` | ```{ "userInfo": UserInfo }``` | `user_info`, with nested `data`, `personal_data`, `address`, and `payment_methods` as needed | Updated `User` | Target endpoint. Current code may temporarily keep `/users/:id/info`, but the target API naming should use `userInfo`. |
| Delete user info | `DELETE /users/:id/user-info` | none | `params[:id]` | Updated `User` or `204 No Content` | Optional endpoint. Useful only if the front-end supports clearing profile data. |
| Add payment method | `POST /users/:id/payment-methods` | ```{ "paymentMethod": PaymentMethod }``` | `payment_method.type`, `payment_method.details` | Updated `User` or created `PaymentMethod` | `details` must remain camelCase because it is opaque JSON shared with Angular. |
| Update payment method | `PATCH /users/:id/payment-methods/:paymentMethodId` | ```{ "paymentMethod": PaymentMethod }``` | `payment_method.type`, `payment_method.details` | Updated `User` or updated `PaymentMethod` | Optional endpoint. Can be skipped if payment methods are always replaced through `userInfo`. |
| Delete payment method | `DELETE /users/:id/payment-methods/:paymentMethodId` | none | `params[:payment_method_id]` | Updated `User` or `204 No Content` | Optional endpoint. |

### 3.2 Product endpoints

| Use case | Endpoint | Angular request body / params | Expected Rails internal params | Expected response | Notes |
|---|---|---|---|---|---|
| Product list | `GET /products` | query params: `page`, `name`, `category`, `minPrice`, `maxPrice` | `page`, `name`, `category`, `min_price`, `max_price` after normalization | `Product[]` | The response may include pagination metadata through headers, for example `X-Total-Pages`. Current code may temporarily accept `min_price` and `max_price`. |
| Product detail | `GET /products/:id` | none | `params[:id]` | `Product` | Normal public product response should not include `createdAt` or `updatedAt`. |
| Categories | `GET /categories` | none | none | `string[]` | Returns distinct product categories. |

### 3.3 Cart endpoints

| Use case | Endpoint | Angular request body / params | Expected Rails internal params | Expected response | Notes |
|---|---|---|---|---|---|
| Create or get current cart | `POST /cart` | ```{}``` | current user from auth token | `Cart` | Creates the cart if missing, otherwise returns the existing current-user cart. |
| Get current cart | `GET /cart` | none | current user from auth token | `Cart` | Cart ownership is inferred from the authenticated user. |
| Add cart item | `POST /cart/items` | ```{ "cartItem": { "productId": 1, "quantity": 2 } }``` | `cart_item.product_id`, `cart_item.quantity` after normalization | `Cart` | Target endpoint. Current code may temporarily keep `/cart/new` and `cart_item.product_id`. |
| Update cart item | `PATCH /cart/items/:productId` | ```{ "cartItem": { "quantity": 3 } }``` | `params[:product_id]`, `cart_item.quantity` | `Cart` | The product identifies the item in the current user's cart. |
| Remove cart item | `DELETE /cart/items/:productId` | none | `params[:product_id]` | `Cart` | Current code may temporarily accept `DELETE /cart/item?product_id=...`. |
| Clear cart | `DELETE /cart` | none | current user from auth token | `204 No Content` or empty `Cart` | Choose one response and keep it consistent. Recommended: return `204 No Content`. |

### 3.4 Checkout and order endpoints

| Use case | Endpoint | Angular request body / params | Expected Rails internal params | Expected response | Notes |
|---|---|---|---|---|---|
| Checkout | `POST /checkout` | ```{ "order": { "items": CartItem[], "personalData": PersonalData, "paymentMethod": PaymentMethod } }``` | `order.items`, `order.personal_data`, `order.payment_method` after normalization | ```{ "orderId": int }``` | `userId` should be derived from the authenticated user, not trusted from the request body. `paymentMethod.details` remains camelCase. |
| User order list | `GET /orders` | none | current user from auth token | `Order[]` | Returns only the authenticated user's orders. |
| User order detail | `GET /orders/:id` | none | `params[:id]`, current user from auth token | `Order` | Must verify the order belongs to the authenticated user. |
| Cancel order | `PATCH /orders/:id/cancel` | none | `params[:id]`, current user from auth token | Updated `Order` | Optional endpoint, only if the front-end supports order cancellation. |

### 3.5 Admin endpoints

| Use case | Endpoint | Angular request body / params | Expected Rails internal params | Expected response | Notes |
|---|---|---|---|---|---|
| Admin current user | `GET /admin/me` | none | current user from auth token | `User` | Must require `role == "ADMIN"`. |
| Admin product list | `GET /admin/products` | optional query params: `page`, `name`, `category` | normalized filter params | `Product[]` | Admin responses may include `createdAt` and `updatedAt` if the admin dashboard needs them. |
| Admin product detail | `GET /admin/products/:id` | none | `params[:id]` | `Product` | Admin response may include metadata omitted from public product responses. |
| Admin create product | `POST /admin/products` | ```{ "product": { "name": string, "description": string, "category": string, "price": float, "stock": int } }``` | `product.name`, `product.description`, `product.category`, `product.price`, `product.stock` | `Product` | Product payload is a request-specific subset of `Product`, without `id`. |
| Admin update product | `PATCH /admin/products/:id` | ```{ "product": { "name?": string, "description?": string, "category?": string, "price?": float, "stock?": int } }``` | normalized `product` params | `Product` | Partial update. |
| Admin delete product | `DELETE /admin/products/:id` | none | `params[:id]` | `204 No Content` | Must require admin role. |
| Admin order list | `GET /admin/orders` | optional query params: `page`, `userId`, `status` | `page`, `user_id`, `status` after normalization | `Order[]` | The `Order` DTO contains `userId`. If admin views need user email, either fetch `User` separately or define an admin-specific order DTO later. |
| Admin order detail | `GET /admin/orders/:id` | none | `params[:id]` | `Order` | Must require admin role. |
| Admin user list | `GET /admin/users` | optional query params: `page`, `email`, `role` | normalized filter params | `User[]` | Admin user responses may include `createdAt` and `updatedAt` if needed by the dashboard. |
| Admin user detail | `GET /admin/users/:id` | none | `params[:id]` | `User` | Must not expose `password_digest`. |
| Admin update user role | `PATCH /admin/users/:id/role` | ```{ "role": "ADMIN" }``` | `params[:id]`, `role` | Updated `User` | Optional endpoint. Useful only if the admin dashboard can manage roles. |

### 3.6 Temporary compatibility notes

During the refactor, the back-end can temporarily accept both the current and target request shapes.

| Current shape | Target shape | Notes |
|---|---|---|
| `{ "info": UserInfo }` | `{ "userInfo": UserInfo }` | Target should match the Angular `User.userInfo` field. |
| `{ "cart_item": { "product_id": 1 } }` | `{ "cartItem": { "productId": 1 } }` | Target keeps HTTP JSON camelCase. Rails normalizes to `cart_item.product_id`. |
| `min_price`, `max_price` query params | `minPrice`, `maxPrice` query params | Target keeps query params consistent with Angular naming. |
| `{ "order_id": 1 }` response | `{ "orderId": 1 }` response | Target response should be camelCase. |
| `PaymentMethod.details.cardHolderName` | unchanged | `details` is opaque JSON and should not be converted to `card_holder_name`. |

---

## 4. Canonical internal Rails shapes

These are the recommended snake_case shapes that Rails services should use internally after request normalization.

Unlike ordinary nested Rails-backed objects, `PaymentMethod.details` should remain camelCase because it is an opaque JSON payload shared with Angular.

### `user_info`

Incoming Angular JSON:

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
    "paymentMethods": [
      {
        "type": "creditCard",
        "details": {
          "cardNumber": "4111111111111111",
          "expiryMonth": 12,
          "expiryYear": 2030,
          "cvv": "123",
          "cardHolderName": "Mario Rossi"
        }
      }
    ]
  }
}
```

Rails internal service params:

```json
{
  "user_info": {
    "data": {
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
    "payment_methods": [
      {
        "type": "creditCard",
        "details": {
          "cardNumber": "4111111111111111",
          "expiryMonth": 12,
          "expiryYear": 2030,
          "cvv": "123",
          "cardHolderName": "Mario Rossi"
        }
      }
    ]
  }
}
```

### `personal_data`

Rails internal shape:

```json
{
  "first_name": "Mario",
  "last_name": "Rossi",
  "phone": "3331234567",
  "address": {
    "street": "Via Roma 1",
    "city": "Ferrara",
    "postal_code": "44121",
    "country": "Italy"
  }
}
```

Serialized to Angular as:

```json
{
  "firstName": "Mario",
  "lastName": "Rossi",
  "phone": "3331234567",
  "address": {
    "street": "Via Roma 1",
    "city": "Ferrara",
    "postalCode": "44121",
    "country": "Italy"
  }
}
```

### `payment_method`

Rails internal shape:

```json
{
  "type": "creditCard",
  "details": {
    "cardNumber": "4111111111111111",
    "expiryMonth": 12,
    "expiryYear": 2030,
    "cvv": "123",
    "cardHolderName": "Mario Rossi"
  }
}
```

Serialized to Angular as:

```json
{
  "type": "creditCard",
  "details": {
    "cardNumber": "4111111111111111",
    "expiryMonth": 12,
    "expiryYear": 2030,
    "cvv": "123",
    "cardHolderName": "Mario Rossi"
  }
}
```

### `order`

Incoming Angular checkout JSON:

```json
{
  "order": {
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

Rails internal service params:

```json
{
  "order": {
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

---

## 5. Known mismatches to fix during refactoring

| Issue | Current state | Target state |
|---|---|---|
| `users.role` | Rails and Angular expect `role`, but the current schema may not contain a `role` column. | Add `role` to `users`, with default `"USER"` and allowed values such as `"USER"` and `"ADMIN"`. |
| `User.info` / `info` wrapper | Some current code uses `info` as the user profile wrapper. | Use `userInfo` in Angular-facing JSON and `user_info` internally in Rails. |
| `UserInfo.data` | Currently may be stored as JSON. | Target model relation should map `data` to a structured `PersonalData` model. |
| `PersonalData.address` | Currently may be embedded JSON. | Target model relation should map `address` to a structured `Address` model. |
| `payment_methods.type` | In Rails, a column named `type` activates Single Table Inheritance by default. | Either rename the column to `method_type`, or explicitly disable STI in the model. |
| `PaymentMethod.details` key conversion | A generic deep snake_case conversion would turn `cardHolderName` into `card_holder_name`. | Treat `details` as opaque JSON and preserve its camelCase keys. |
| `cart_item.product_id` request body | Current code may use Rails-style snake_case JSON in requests. | Target HTTP JSON should use `cartItem.productId`, then normalize at the API boundary. |
| Product filters | Current Angular/Rails code may use `min_price` and `max_price`. | Target HTTP query params should use `minPrice` and `maxPrice`, then normalize to `min_price` and `max_price`. |
| Checkout user identity | Current checkout payload may include `userId`. | Back-end should derive `user_id` from the authenticated user token and ignore any request-provided `userId`. |
| Checkout response | Current response may use `order_id`. | Target response should use `orderId`. |
| `orders.items` | Orders may currently store items as JSON. | Prefer a relational order-items structure if available. If `orders.items` remains JSON, document it as an immutable snapshot. |

---

## 6. Serializer targets

The refactor should create explicit serializers that produce the Angular JSON shapes above.

Suggested serializers:

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

Each serializer should:

1. Select only fields that belong to the public API.
2. Convert Rails-backed fields to camelCase before rendering.
3. Avoid exposing internal Rails/database-only fields such as `password_digest`.
4. Preserve opaque JSON payloads such as `PaymentMethod.details` without converting their internal keys.

---

## 7. Request normalization target

The refactor should create one request-normalization utility or controller concern.

Target behavior:

```txt
incoming JSON body:
{
  "userInfo": {
    "data": {
      "firstName": "Mario",
      "address": {
        "postalCode": "44121"
      }
    },
    "paymentMethods": [
      {
        "type": "creditCard",
        "details": {
          "cardHolderName": "Mario Rossi"
        }
      }
    ]
  }
}

Rails internal params:
{
  "user_info" => {
    "data" => {
      "first_name" => "Mario",
      "address" => {
        "postal_code" => "44121"
      }
    },
    "payment_methods" => [
      {
        "type" => "creditCard",
        "details" => {
          "cardHolderName" => "Mario Rossi"
        }
      }
    ]
  }
}
```

Important exception:

```txt
PaymentMethod.details must not be deep-converted.
```

This lets Angular remain camelCase and Rails remain snake_case without duplicating conversion code inside every controller.