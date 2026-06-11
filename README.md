# Shop Backend

Backend Ruby on Rails in modalita API per il progetto full-stack di *Progetto di Sistemi Web*.
Espone le API REST usate dal frontend Angular per prodotti, carrello persistente, checkout, ordini, autenticazione e area admin.

## Tecnologie

- Ruby `3.4.7`
- Ruby on Rails `8.1.2`
- Bundler `4.0.1`
- SQLite
- Active Record
- Rails API controllers
- JWT per autenticazione
- CORS per integrazione con Angular

## Quick Start Full Stack

Terminale backend:

```bash
cd shop-backend
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

Terminale frontend:

```bash
cd shop-frontend
npm install
npm start
```

Backend atteso:

```text
http://localhost:3000
```

Frontend atteso:

```text
http://localhost:4200
```

## Setup Backend

Installare le dipendenze:

```bash
bundle install
```

Creare e preparare il database:

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

Il seed crea il catalogo prodotti iniziale. Se serve un utente admin locale,
crearlo dalla Rails console:

```bash
bin/rails console
```

```ruby
User.find_or_create_by!(email: "admin@example.com") do |user|
  user.password = "secret123"
  user.role = "ADMIN"
end
```

Avviare il server:

```bash
bin/rails server
```

## Schema Dati

Le principali tabelle del dominio sono:

```text
users
user_infos
personal_data
addresses
payment_methods
products
carts
cart_items
orders
order_items
```

Il profilo utente e l'indirizzo sono normalizzati in tabelle relazionali.
Gli ordini mantengono snapshot JSON per dati personali e metodo di pagamento, così lo storico resta immutabile anche se il profilo viene modificato dopo l'acquisto.
I prodotti acquistati sono salvati in `order_items` con prezzo e quantità al momento dell'ordine.

## Modelli Principali

- `User`: account autenticato, password digest e ruolo `USER` o `ADMIN`.
- `UserInfo`: contenitore del profilo collegato a dati personali e metodi di pagamento.
- `PersonalData` e `Address`: dati anagrafici e indirizzo di spedizione.
- `PaymentMethod`: metodo di pagamento con `method_type` e dettagli JSON opachi.
- `Product`: prodotto del catalogo con nome, descrizione, categoria, prezzo e stock.
- `Cart` e `CartItem`: carrello persistente dell'utente autenticato.
- `Order` e `OrderItem`: ordine creato dal checkout e righe acquistate.

## API Principali

### Autenticazione

```text
POST /auth/login
POST /auth/logout
GET /auth/me
```

Le richieste protette usano:

```text
Authorization: Bearer <token>
```

### Utenti

```text
POST /users
GET /users/:id
PATCH /users/:id/user-info
```

### Prodotti

```text
GET /products
GET /products/:id
GET /categories
```

`GET /products` supporta:

```text
page
name
category
minPrice
maxPrice
```

La paginazione espone il numero di pagine tramite header `X-Total-Pages`.

### Carrello

```text
GET /cart
POST /cart
POST /cart/items
PATCH /cart/items/:productId
DELETE /cart/items/:productId
DELETE /cart
```

Il carrello è associato all'utente autenticato e viene ricaricato dal backend dopo refresh della pagina.

### Ordini

```text
POST /orders
GET /orders
GET /orders/:id
```

`POST /orders` crea un ordine per l'utente autenticato, decrementa lo stock dei prodotti e svuota il carrello.
`GET /orders` supporta filtri per `status`, `fromDate` e `toDate`.

### Admin

```text
GET /admin/me
GET /admin/products
GET /admin/products/:id
POST /admin/products
PATCH /admin/products/:id
DELETE /admin/products/:id
GET /admin/orders
GET /admin/orders/:id
PATCH /admin/orders/:id/status
GET /admin/users
GET /admin/users/:id
```

Gli endpoint admin richiedono ruolo `ADMIN`.
L'admin puo creare, modificare ed eliminare prodotti, consultare ordini e utenti registrati, confermare ordini o annullarli.
Quando un ordine passa a `cancelled`, lo stock dei prodotti viene ripristinato.

## Flusso Applicativo

1. L'utente effettua login e riceve un token JWT.
2. Il frontend usa il token per chiamare risorse protette.
3. L'utente consulta i prodotti pubblici e aggiunge articoli al carrello.
4. Il carrello viene persistito nel database ed è ricaricabile.
5. Il checkout invia dati personali, pagamento e articoli.
6. Il backend crea ordine e righe ordine, salva snapshot storici e decrementa lo stock.
7. L'utente consulta lista e dettaglio dei propri ordini.
8. L'admin gestisce prodotti e aggiorna lo stato degli ordini.

## Funzionalità Avanzate

- Area admin protetta da ruolo lato backend.
- CRUD completo prodotti lato admin.
- Lista utenti registrati lato admin, con esclusione degli utenti admin.
- Consultazione ordini lato admin.
- Conferma/annullamento ordini da admin.
- Ripristino automatico dello stock quando un ordine viene annullato.
- Filtri ordini utente per stato e data.

## Test e Verifica

Eseguire i test backend:

```bash
bin/rails test
```

Verifica manuale consigliata:

1. Avviare backend e frontend.
2. Eseguire registrazione e login.
3. Consultare prodotti e dettaglio prodotto.
4. Aggiungere prodotti al carrello e verificare persistenza dopo refresh.
5. Completare checkout.
6. Consultare lista e dettaglio ordini.
7. Accedere come admin.
8. Creare/modificare/eliminare un prodotto.
9. Aprire un ordine admin e confermarlo o annullarlo.

## Note

Questo repository contiene solo il backend Rails.
Il frontend Angular è in un repository separato e deve essere avviato insieme al backend per provare il flusso full-stack completo.
