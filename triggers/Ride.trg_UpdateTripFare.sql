USE SnapProject;
GO

CREATE TRIGGER Ride.trg_UpdateTripFare
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
END;
GO  