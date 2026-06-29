customers
---------
customer_id PK
name
phone
wallet_balance

restaurants
---------
restaurant_id PK
name
address

orders
---------
order_id PK
customer_id FK
restaurant_id FK
status
total_price

order_items
---------
item_id PK
order_id FK
menu_id FK
quantity