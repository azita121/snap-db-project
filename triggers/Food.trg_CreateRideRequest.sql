USE SnapProject;
GO

CREATE TRIGGER Food.trg_CreateRideRequest
ON Food.FoodPayment
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE o
    SET Status = 'WaitingForCourier'
    FROM Food.CustomerOrder o
    INNER JOIN inserted i
        ON o.OrderID = i.OrderID
    WHERE i.PaymentStatus = 'Paid';

    INSERT INTO Ride.RideRequest
    (
        PassengerID,
        PickupLocationID,
        DestinationLocationID,
        DriverID,
        Status,
        EstimatedFare
    )
    SELECT
        o.CustomerID,
        1,
        2,
        NULL,
        'Pending',
        50000
    FROM Food.CustomerOrder o
    INNER JOIN inserted i
        ON o.OrderID = i.OrderID
    WHERE i.PaymentStatus = 'Paid';
END;
GO