USE SnapProject;
GO

CREATE PROCEDURE Ride.sp_CreateRideRequest
    @PassengerID INT,
    @PickupLocationID INT,
    @DestinationLocationID INT,
    @DriverID INT = NULL,
    @EstimatedFare DECIMAL(10,2)
AS
BEGIN
    INSERT INTO Ride.RideRequest
    (
        PassengerID,
        PickupLocationID,
        DestinationLocationID,
        DriverID,
        EstimatedFare
    )
    VALUES
    (
        @PassengerID,
        @PickupLocationID,
        @DestinationLocationID,
        @DriverID,
        @EstimatedFare
    );
END;
GO