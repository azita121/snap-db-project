USE [SnapProject]
GO

/****** Object:  UserDefinedFunction [Ride].[fn_GetTripCount]    Script Date: 7/13/2026 5:53:46 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE FUNCTION [Ride].[fn_GetTripCount]
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


