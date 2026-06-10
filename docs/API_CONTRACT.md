# API Contract

This document fixes the JSON contract expected by the Angular front-end and maps each API-facing object to the current Ruby/Rails database schema.

The rule for the refactoring is:

- Angular-facing JSON uses `camelCase`.
- Rails models, database columns, services, and internal params use `snake_case`.
- Conversion between the two formats must happen only at the API boundary:
  - request parsing: `camelCase` JSON -> `snake_case` Rails params
  - response serialization: Rails model/data -> `camelCase` JSON

---

## 1. Naming convention

| Layer | Naming convention | Example |
|---|---|---|
| Angular DTOs | `camelCase` | `personalData`, `paymentMethod`, `postalCode`, `createdAt` |
| HTTP request JSON | `camelCase` | `{ "order": { "personalData": ... } }` |
| HTTP response JSON | `camelCase` | `{ "userId": 1, "createdAt": "..." }` |
| Rails models | `snake_case` | `personal_data`, `payment_method`, `postal_code`, `created_at` |
| Database columns | `snake_case` | `user_id`, `created_at`, `postal_code` |

---

## 2. Domain JSON objects

| Angular type | Angular JSON shape | Rails model / schema mapping | Refactoring notes |
|---|---|---|---|
| `User` | ```json { "id": int, "email": string, "password": string, "token": string, "role": string, "userInfo": UserInfo }``` | `User` model -> `users` table: `id`, `email`, `password_digest`, `user_info`, `role`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary: for example, the admin users list page would be able to see when the user has registered their profile, or last updated it. |
| `UserInfo` | ```json { "data?": PersonalData, "paymentMethods?": PaymentMethod[] }``` | `UserInfo` model -> `user_infos` table: `id`, `user_id`, `data`, `payment_methods`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary: for example, the admin users list page would be able to see when the user has registered their profile, or last updated it. `data` and `paymentMethods` are optional fields: they can be `null`, and are not strictly required to have a set value. |
| `PersonalData` | ```json { "firstName": string, "lastName": string, "phone": string, "address": Address }``` | `PersonalData` model -> `personal_data` table: `id`, `user_info_id`, `first_name`, `last_name`, `phone`, `address`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary: for example, the admin users list page would be able to see when the user has registered their profile, or last updated it. |
| `Address` | ```json { "street": string, "city": string, "postalCode": string, "country": string }``` | `Address` model -> `addresses` table: `id`, `personal_data_id`, `street`, `city`, `postal_code`, `country`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary: for example, the admin users list page would be able to see when the user has registered their profile, or last updated it. |
| `PaymentMethod<T = CreditCard \| PayPal>` | ```json { "type": string, "details": T } ``` | `PaymentMethod` model -> `payment_methods` table: `id`, `user_info_id`, `type`, `details`, `created_at`, `updated_at`. | `details` is a column that can contain JSON data formatted in a different way, depending on the `type` itself. `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary. |
| `CreditCard` | ```json { "cardNumber": string, "expiryMonth": int, "expiryYear": int, "cvv": "sstring, "cardHolderName": string } ``` | Stored inside `payment_methods.details` as regular JSON. | As this model is not stored in a table, it doesn't need to be manually converted between `snake_case` and `camelCase`, as it will be always treated with the Angular-friendly `camelCase` naming notation. |
| `PayPal` | ```json { "email": "user@example.com" } ``` | Stored inside `payment_methods.details` as regular JSON. | As this model is not stored in a table, it doesn't need to be manually converted between `snake_case` and `camelCase`, as it will be always treated with the Angular-friendly `camelCase` naming notation. |
| `Product` | ```json { "id": int, "name": string, "description": string, "category": string, "price": float, "stock": string }``` | `Product` model -> `products` table: `id`, `name`, `description`, `category`, `price`, `stock`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary: for example, the admin products list page would be able to see when a product has been added to the stock, or updated from the database from the administrator dashboard. |
| `Cart` | ```json { "id": int, "user": User, "items": CartItem[] } ``` | `Cart` model -> `carts` table: `id`, `user_id`, `items`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary. |
| `CartItem` | ```json { "product": Product, "quantity": int } ``` | `CartItem` model -> `cart_items` table: `id`, `cart_id`, `product_id`, `quantity`, `created_at`, `updated_at`. | `created_at` and `updated_at` are columns that should not be returned as part of a JSON response, unless necessary. |
| `Order` | ```json { "id": int, "userId": int, "items": CartItem[], "personalData": PersonalData,  "paymentMethod": PaymentMethod, "createdAt": string } ``` | `Order` model -> `orders` table: `id`, `user_id`, `items`, `personal_data`, `payment_method`, `created_at`, `updated_at`. | `updated_at` is a column that should not be returned as part of a JSON response, unless necessary. `personalData` and `paymentMethod` are separate, required fields used in substitution of a generic `User` object, because a `User` model has an *optional* `"personalData": PersonalData` field and an *optional, array* `"paymentMethods": PaymentMethod[]` field. |

---

## 3. Request and response wrappers

These are not full domain models, but they are part of the HTTP contract used by Angular services.

| Use case | Endpoint | Angular request body / params | Expected Rails internal params | Expected response |
|---|---|---|---|---|
| Login | `POST /login` | ```json { "email": "user@example.com", "password": "secret" } ``` | `email`, `password` | `User` with `token`, `id`, `email`, `role` |
| Register | `POST /users` | ```json { "email": "user@example.com", "password": "secret" } ``` | `email`, `password` | `User` with `token`, `id`, `email`, `role` |
| Get current/full user | `GET /users/:id` | none | `params[:id]` | `User` with nested `info` |
| Update user info | `PATCH /users/:id/info` | ```json { "info": UserInfo } ``` | `info.data`, `info.payment_methods` after normalization | Updated `User` |
| Product list | `GET /products` | query params: `page`, `name`, `category`, `min_price`, `max_price` currently | Recommended future internal params: `page`, `name`, `category`, `min_price`, `max_price` | `Product[]`; paginated endpoint also uses `X-Total-Pages` header |
| Product detail | `GET /products/:id` | none | `params[:id]` | `Product` |
| Categories | `GET /categories` | none | none | `string[]` |
| Create cart | `POST /cart` | ```json {} ``` | current user from token | `Cart` |
| Get cart | `GET /cart` | none | current user from token | `Cart` |
| Add cart item | `POST /cart/new` | ```json { "cart_item": { "product_id": 1, "quantity": 2 } } ``` | `cart_item.product_id`, `cart_item.quantity` | `Cart` |
| Update cart item | `PATCH /cart/item` | ```json { "cart_item": { "product_id": 1, "quantity": 3 } } ``` | `cart_item.product_id`, `cart_item.quantity` | `Cart` |
| Remove cart item | `DELETE /cart/item` | query param: `product_id=1` | `params[:product_id]` | `Cart` |
| Clear cart | `DELETE /cart` | none | current user from token | `204 No Content` or new/empty `Cart` depending final decision |
| Checkout | `POST /checkout` | ```json { "order": Order } ``` | `order.personal_data`, `order.payment_method`, `order.items`, `order.user_id` after normalization | Recommended: ```json { "orderId": 1 } ``` |
| User order list | `GET /orders` | none | current user from token | `Order[]` |
| User order detail | `GET /orders/:id` | none | `params[:id]`, current user from token | `Order` |
| Admin current user | `GET /admin/me` | none | current user from token | `User` |
| Admin product list | `GET /admin/products` | none | admin user from token | `Product[]` |
| Admin create product | `POST /admin/products` | ```json { "product": ProductPayload } ``` | `product.name`, `product.description`, `product.category`, `product.price`, `product.stock` | `Product` |
| Admin update product | `PATCH /admin/products/:id` | ```json { "product": Partial<ProductPayload> } ``` | normalized `product` params | `Product` |
| Admin delete product | `DELETE /admin/products/:id` | none | `params[:id]` | `204 No Content` |
| Admin order list | `GET /admin/orders` | none | admin user from token | `Order[]`, with `user` populated |
| Admin order detail | `GET /admin/orders/:id` | none | `params[:id]`, admin user from token | `Order`, with `user` populated |
| Admin user list | `GET /admin/users` | none | admin user from token | `AdminUser[]` |
| Admin user detail | `GET /admin/users/:id` | none | `params[:id]`, admin user from token | `AdminUser` |

---

## 4. Canonical internal Rails shapes

These are the recommended snake_case shapes that Rails services should use internally after request normalization.

### `personal_data`

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