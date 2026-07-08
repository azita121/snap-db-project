INSERT INTO Food.Customer
(FirstName, LastName, PhoneNumber, Email, WalletBalance)
VALUES
('Ali',   'Ahmadi',     '09120000001', 'ali@gmail.com',   250000),
('Sara',  'Mohammadi',  '09120000002', 'sara@gmail.com',  180000),
('Reza',  'Karimi',     '09120000003', 'reza@gmail.com',  320000),
('Negin', 'Hosseini',   '09120000004', 'negin@gmail.com', 500000),
('Amir',  'Jafari',     '09120000005', 'amir@gmail.com',  150000);
GO

INSERT INTO Food.Restaurant
(Name, PhoneNumber, Address, Latitude, Longitude, WalletBalance, IsOpen)
VALUES
(N'رستوران آفتاب', '02111111111', N'تهران، ولیعصر', 35.689200, 51.389000, 1000000, 1),

(N'پیتزا سیب', '02122222222', N'تهران، ستارخان', 35.700100, 51.350000, 800000, 1),

(N'کبابی سنتی', '02133333333', N'کرج، عظیمیه', 35.840000, 50.939000, 650000, 1),

(N'برگر لند', '02144444444', N'اصفهان، چهارباغ', 32.654600, 51.668000, 450000, 1),

(N'کافه بهار', '02155555555', N'شیراز، معالی‌آباد', 29.591800, 52.583700, 900000, 1);
GO

INSERT INTO Food.FoodItem
(RestaurantID, CategoryID, FoodName, Price, IsAvailable)
VALUES
(1,1,N'چلوکباب کوبیده',180000,1),
(2,2,N'پیتزا پپرونی',250000,1),
(3,3,N'برگر مخصوص',220000,1),
(4,4,N'آب پرتقال طبیعی',70000,1),
(5,5,N'چیزکیک',95000,1);
GO

INSERT INTO Food.Menu (RestaurantID, MenuName)

VALUES

(1,N'منوی اصلی'),

(2,N'منوی پیتزا'),

(3,N'منوی برگر'),

(4,N'منوی نوشیدنی'),

(5,N'منوی دسر');
GO

INSERT INTO Food.MenuItem (MenuID, FoodID)

VALUES

(1,1),

(2,2),

(3,3),

(4,4),

(5,5);
GO

INSERT INTO Food.CustomerOrder
(CustomerID, RestaurantID, Status, TotalPrice)
VALUES
(1,1,'Pending',180000),
(2,2,'Preparing',250000),
(3,3,'Delivered',220000),
(4,4,'Pending',70000),
(5,5,'Pending',95000);
GO

INSERT INTO Food.OrderItem
(OrderID, FoodID, Quantity, UnitPrice)
VALUES
(1,1,1,180000),
(2,2,1,250000),
(3,3,1,220000),
(4,4,1,70000),
(5,5,1,95000);
GO

INSERT INTO Food.FoodCoupon
(CouponCode, DiscountPercent, ExpireDate, IsActive)
VALUES
('OFF10',10,'2026-12-31',1),
('OFF20',20,'2026-12-31',1),
('WELCOME',15,'2026-10-31',1),
('SUMMER',25,'2026-09-30',1),
('VIP30',30,'2026-12-31',1);
GO

INSERT INTO Food.FoodPayment
(OrderID, Amount, PaymentMethod, PaymentStatus)
VALUES
(1,180000,'Wallet','Paid'),
(2,250000,'Online','Paid'),
(3,220000,'Wallet','Paid'),
(4,70000,'Cash','Pending'),
(5,95000,'Online','Paid');
GO