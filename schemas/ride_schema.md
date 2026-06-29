drivers

\---------

driver\_id PK

name

status



vehicles

\---------

vehicle\_id PK

driver\_id FK



trips

\---------

trip\_id PK

driver\_id FK

passenger\_id FK



driver\_locations

\---------

driver\_id FK

latitude

longitude

