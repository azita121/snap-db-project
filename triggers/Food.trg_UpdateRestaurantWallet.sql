CREATE TRIGGER Food.trg_UpdateRestaurantWallet
ON Food.Payment
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- کد افزایش موجودی رستوران

    INSERT INTO Food.Log
    (
        EventType,
        Description
    )
    VALUES
    (
        'Restaurant Wallet',
        'Restaurant wallet updated.'
    );
END;
GO