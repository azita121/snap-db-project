INSERT INTO Ride.Driver
(FirstName, LastName, PhoneNumber, NationalCode, LicenseNumber, WalletBalance, IsOnline, IsAvailable, Rating)
VALUES
('Mohammad','Ahmadi','09131111111','1111111111','DRV1001',500000,1,1,4.8),
('Ali','Karimi','09131111112','2222222222','DRV1002',350000,1,1,4.6),
('Reza','Mohammadi','09131111113','3333333333','DRV1003',700000,0,1,4.9),
('Saeed','Hosseini','09131111114','4444444444','DRV1004',250000,1,0,4.5),
('Amir','Jafari','09131111115','5555555555','DRV1005',900000,1,1,5.0);
GO

INSERT INTO Ride.Passenger
(FirstName, LastName, PhoneNumber, Email, WalletBalance)
VALUES
('Ali','Ahmadi','09121111111','ali@gmail.com',300000),
('Sara','Mohammadi','09121111112','sara@gmail.com',450000),
('Reza','Karimi','09121111113','reza@gmail.com',200000),
('Negin','Hosseini','09121111114','negin@gmail.com',600000),
('Amir','Jafari','09121111115','amir@gmail.com',150000);
GO

INSERT INTO Ride.Location
(Address, Latitude, Longitude)
VALUES
(N'تهران، ولیعصر',35.6892000,51.3890000),
(N'تهران، آزادی',35.7000000,51.3370000),
(N'کرج، عظیمیه',35.8400000,50.9390000),
(N'اصفهان، چهارباغ',32.6546000,51.6680000),
(N'شیراز، معالی‌آباد',29.5918000,52.5837000);
GO

INSERT INTO Ride.Vehicle
(DriverID, PlateNumber, Brand, Model, Color, ManufactureYear)
VALUES
(1,'11الف11111','Peugeot','206',N'سفید',2020),
(2,'22ب22222','Saipa','Tiba',N'مشکی',2019),
(3,'33ج33333','Toyota','Corolla',N'نقره‌ای',2022),
(4,'44د44444','Hyundai','Elantra',N'آبی',2021),
(5,'55ه55555','Kia','Cerato',N'قرمز',2023);
GO

INSERT INTO Ride.DriverLocation
(DriverID, LocationID)
VALUES
(1,1),
(2,2),
(3,3),
(4,4),
(5,5);
GO

INSERT INTO Ride.RideRequest
(PassengerID, PickupLocationID, DestinationLocationID, DriverID, Status, EstimatedFare)
VALUES
(1,1,2,1,'Accepted',120000),
(2,2,3,2,'Accepted',95000),
(3,3,4,3,'Completed',180000),
(4,4,5,4,'Pending',80000),
(5,5,1,5,'Completed',150000);
GO

INSERT INTO Ride.Trip
(RequestID, StartTime, EndTime, Distance, FinalFare, Status)
VALUES
(1,GETDATE(),DATEADD(MINUTE,20,GETDATE()),12.5,120000,'Completed'),
(2,GETDATE(),DATEADD(MINUTE,15,GETDATE()),8.3,95000,'Completed'),
(3,GETDATE(),DATEADD(MINUTE,30,GETDATE()),18.7,180000,'Completed'),
(4,NULL,NULL,NULL,NULL,'Waiting'),
(5,GETDATE(),DATEADD(MINUTE,25,GETDATE()),15.2,150000,'Completed');
GO

INSERT INTO Ride.RidePayment
(TripID, Amount, PaymentMethod, PaymentStatus)
VALUES
(1,120000,'Wallet','Paid'),
(2,95000,'Online','Paid'),
(3,180000,'Cash','Paid'),
(4,NULL,NULL,'Pending'),
(5,150000,'Wallet','Paid');
GO

INSERT INTO Ride.DriverWalletTransaction
(DriverID, Amount, TransactionType, Description)
VALUES
(1,120000,'Credit',N'کرایه سفر شماره 1'),
(2,95000,'Credit',N'کرایه سفر شماره 2'),
(3,180000,'Credit',N'کرایه سفر شماره 3'),
(4,0,'Pending',N'سفر در انتظار'),
(5,150000,'Credit',N'کرایه سفر شماره 5');
GO

INSERT INTO Ride.RideCoupon
(Code, DiscountPercent, ExpireDate, MaxUsage)
VALUES
('RIDE10',10,'2026-12-31',100),
('RIDE20',20,'2026-12-31',50),
('WELCOME15',15,'2026-11-30',200),
('SUMMER25',25,'2026-09-30',30),
('VIP30',30,'2026-12-31',20);
GO