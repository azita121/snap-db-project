USE SnapProject;
GO

ALTER TRIGGER Food.trg_SetOrderTotal
ON Food.OrderItem
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE co
    SET TotalPrice =
    (
        SELECT SUM(oi.Quantity * oi.UnitPrice)
        FROM Food.OrderItem oi
        WHERE oi.OrderID = co.OrderID
    )
    FROM Food.CustomerOrder co
    INNER JOIN inserted i
        ON co.OrderID = i.OrderID;

    INSERT INTO Food.Log
    (
        EventType,
        Description
    )
    سVALUES
    (
        'Order Total',
        'Order total calculated automatically.'
    );
END;
GO