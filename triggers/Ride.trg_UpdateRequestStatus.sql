USE SnapProject;
GO

CREATE TRIGGER Ride.trg_UpdateRequestStatus
ON Ride.Trip
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE rr
    SET Status = 'Completed'
    FROM Ride.RideRequest rr
    INNER JOIN inserted i
        ON rr.RequestID = i.RequestID;
END;
GO