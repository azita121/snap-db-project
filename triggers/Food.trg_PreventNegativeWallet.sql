USE SnapProject;
GO

ALTER TRIGGER Food.trg_PreventNegativeWallet
ON Food.Customer
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE WalletBalance < 0
    )
    BEGIN
        RAISERROR ('Customer wallet balance cannot be negative.',16,1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    INSERT INTO Food.Log
    (
        EventType,
        Description
    )
    VALUES
    (
        'Wallet Check',
        'Customer wallet validation executed.'
    );
END;
GO