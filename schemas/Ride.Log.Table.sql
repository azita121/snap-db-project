USE SnapProject;
GO

ALTER TRIGGER Ride.trg_UpdateTripFare
ON Ride.RidePayment
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE t
    SET FinalFare = i.Amount
    FROM Ride.Trip t
    INNER JOIN inserted i
        ON t.TripID = i.TripID
    WHERE i.PaymentStatus = 'Paid';

    INSERT INTO Ride.Log
    (
        EventType,
        Description
    )
    SELECT
        'Payment',
        CONCAT('Payment registered for TripID ', TripID)
    FROM inserted;
END;
GO