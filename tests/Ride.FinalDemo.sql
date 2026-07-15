USE SnapProject;
GO

-- مشاهده درخواست‌های ایجاد شده

SELECT *
FROM Ride.RideRequest;

-- پرداخت سفر

INSERT INTO Ride.RidePayment
(
    TripID,
    Amount,
    PaymentMethod,
    PaymentStatus
)
VALUES
(
    1,
    50000,
    'Online',
    'Paid'
);

-- مشاهده سفرها

SELECT *
FROM Ride.Trip;

-- مشاهده Log

SELECT *
FROM Ride.Log
ORDER BY LogID DESC;