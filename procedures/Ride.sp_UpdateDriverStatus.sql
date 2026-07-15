USE SnapProject;
GO

CREATE PROCEDURE Ride.sp_UpdateDriverStatus
    @DriverID INT,
    @IsOnline BIT,
    @IsAvailable BIT
AS
BEGIN
    UPDATE Ride.Driver
    SET
        IsOnline = @IsOnline,
        IsAvailable = @IsAvailable
    WHERE DriverID = @DriverID;
END;
GO