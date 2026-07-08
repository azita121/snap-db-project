USE SnapProject;
GO

CREATE PROCEDURE Ride.sp_AddDriverWalletTransaction
    @DriverID INT,
    @Amount DECIMAL(10,2),
    @TransactionType NVARCHAR(20),
    @Description NVARCHAR(200)
AS
BEGIN
    INSERT INTO Ride.DriverWalletTransaction
    (
        DriverID,
        Amount,
        TransactionType,
        Description
    )
    VALUES
    (
        @DriverID,
        @Amount,
        @TransactionType,
        @Description
    );
END;
GO