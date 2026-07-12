USE SnapProject;
GO

-- Test 1: PreventNegativeDriverWallet
UPDATE Ride.Driver
SET WalletBalance = -100
WHERE DriverID = 1;
GO

-- Test 2: UpdateRequestStatus
INSERT INTO Ride.Trip
(
    RequestID,
    DriverID,
    FinalFare
)
VALUES
(
    1,
    1,
    0
);
GO

-- Test 3: UpdateTripFare
INSERT INTO Ride.RidePayment
(
    TripID,
    Amount,
    PaymentStatus
)
VALUES
(
    1,
    250000,
    'Paid'
);
GO

-- Check Log
SELECT *
FROM Ride.Log
ORDER BY LogID DESC;
GO