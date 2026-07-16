# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here is idempotent so it can be executed at any time.
# Load with `bin/rails db:seed` or during `db:setup`.

# Lista prodotti (idempotente: usa `find_or_initialize_by(name:)`)
products = [

  # Prodotti forniti dall'utente (30 elementi)
  { name: 'Smartphone X200', category: 'Elettronica', price: 499.99, stock: 25, description: 'Smartphone 6.5" Full HD, 128GB storage, 8GB RAM, doppia fotocamera, batteria 4500mAh.' },
  { name: 'Cuffie Wireless Nova', category: 'Elettronica', price: 89.90, stock: 100, description: 'Cuffie Bluetooth con cancellazione attiva del rumore, autonomia 30h, microfono integrato.' },
  { name: 'T-shirt Essential', category: 'Abbigliamento', price: 19.99, stock: 150, description: 'T-shirt 100% cotone, taglio regular, disponibile in più colori.' },
  { name: 'Giacca Invernale Arctic', category: 'Abbigliamento', price: 129.50, stock: 60, description: 'Giacca imbottita, resistente all\'acqua, fodera termica per climi freddi.' },
  { name: 'Il Sentiero', category: 'Libri', price: 14.90, stock: 80, description: 'Romanzo contemporaneo, 320 pagine, narrativa italiana.' },
  { name: 'Guida al Web Dev', category: 'Libri', price: 29.99, stock: 40, description: 'Guida pratica a HTML, CSS e JavaScript per sviluppatori web.' },
  { name: 'Lampada da Tavolo Lumo', category: 'Casa', price: 39.90, stock: 70, description: 'Lampada LED dimmerabile con braccio regolabile, ottima per scrivanie.' },
  { name: 'Set Posate Elegance (24pz)', category: 'Casa', price: 59.00, stock: 45, description: 'Set posate in acciaio inox satinato, 24 pezzi per servizio da 6.' },
  { name: 'Tagliaerba Elettrico LawnMaster', category: 'Giardino', price: 249.00, stock: 15, description: 'Tagliaerba elettrico compatto, larghezza taglio 40cm, adatto a giardini fino a 600m².' },
  { name: 'Pallone da Calcio ProMatch', category: 'Sport', price: 34.99, stock: 120, description: 'Pallone da calcio regolamentare, cuciture rinforzate, superficie resistente all\'acqua.' },

  { name: 'Smartwatch Pulse', category: 'Elettronica', price: 199.99, stock: 85, description: 'Smartwatch con monitoraggio battito cardiaco, GPS integrato, notifiche smartphone.' },
  { name: 'Router AC1200 HomeNet', category: 'Elettronica', price: 59.99, stock: 200, description: 'Router dual-band con porte Gigabit e installazione semplificata.' },
  { name: 'SSD NVMe 1TB Velocity', category: 'Elettronica', price: 119.00, stock: 50, description: 'SSD NVMe M.2 1TB, velocità di lettura fino a 3500MB/s.' },
  { name: 'Action Camera TrailCam', category: 'Elettronica', price: 149.90, stock: 30, description: 'Action camera 4K resistente all\'acqua fino a 30m, stabilizzazione elettronica.' },

  { name: 'Jeans Regular Fit', category: 'Abbigliamento', price: 49.90, stock: 120, description: 'Jeans in denim elasticizzato, vestibilità regular.' },
  { name: 'Scarpe Running Aero', category: 'Abbigliamento', price: 89.00, stock: 90, description: 'Scarpe da corsa leggere con ammortizzazione e suola traspirante.' },
  { name: 'Sciarpa Lana Merino', category: 'Abbigliamento', price: 24.50, stock: 200, description: 'Sciarpa in lana merino, morbida e calda.' },
  { name: 'Zaino CityPack', category: 'Abbigliamento', price: 69.00, stock: 75, description: 'Zaino urbano con scomparto per laptop 15\", resistente all\'acqua.' },

  { name: 'Cucina Mediterranea', category: 'Libri', price: 21.50, stock: 60, description: 'Raccolta di ricette tradizionali mediterranee con fotografie passo-passo.' },
  { name: 'Notte Senza Nome', category: 'Libri', price: 16.00, stock: 45, description: 'Thriller psicologico avvincente, 380 pagine.' },
  { name: 'Ruby on Rails Avanzato', category: 'Libri', price: 34.90, stock: 25, description: 'Approfondimenti su performance, sicurezza e architetture Rails.' },

  { name: 'Coperta Plaid Cozy', category: 'Casa', price: 29.90, stock: 110, description: 'Coperta morbida 130x170 cm, ideale per salotto o camera da letto.' },
  { name: 'Set Tazze Ceramica (4pz)', category: 'Casa', price: 22.50, stock: 85, description: 'Set di 4 tazze in ceramica con finitura lucida.' },
  { name: 'Mensola a Muro Nordic', category: 'Casa', price: 45.00, stock: 40, description: 'Mensola in legno massello con design nordico, montaggio a muro.' },

  { name: 'Irrigatore Smart Garden', category: 'Giardino', price: 39.50, stock: 60, description: 'Irrigatore regolabile con timer, compatibile con sistemi smart home.' },
  { name: 'Vasi in Terracotta (set 3)', category: 'Giardino', price: 34.00, stock: 90, description: 'Set di 3 vasi in terracotta di diverse misure, ideali per piante da balcone.' },
  { name: 'Forbici da Potatura Pro', category: 'Giardino', price: 19.99, stock: 150, description: 'Forbici ergonomiche per potatura con lama in acciaio temperato.' },

  { name: 'Racchetta da Tennis ProSpin', category: 'Sport', price: 129.00, stock: 35, description: 'Racchetta da tennis bilanciata per giocatori intermedi e avanzati.' },
  { name: 'Borsa da Palestra FitGear', category: 'Sport', price: 44.90, stock: 95, description: 'Borsa sportiva capiente con scomparto per calzature e tasche multiple.' },
  { name: 'Tappetino Yoga Balance', category: 'Sport', price: 25.00, stock: 140, description: 'Tappetino antiscivolo spesso 6mm, ideale per yoga e pilates.' }
]

Product.transaction do
  products.each do |attrs|
    p = Product.find_or_initialize_by(name: attrs[:name])
    p.assign_attributes(attrs)
    p.save!
  end
end

puts "Seeded #{products.size} products (created or updated)."
