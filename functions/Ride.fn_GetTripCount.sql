USE SnapProject;
GO

CREATE FUNCTION Ride.fn_GetTripCount
(
    @DriverID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @TripCount INT;

    SELECT @TripCount = COUNT(*)
    FROM Ride.Trip T
    INNER JOIN Ride.RideRequest R
        ON T.RequestID = R.RequestID
    WHERE R.DriverID = @DriverID;

    RETURN ISNULL(@TripCount, 0);
END;
GO