import PowerSync

/// Client-side schema. PowerSync stores everything in SQLite with three types:
/// text, integer, real. UUIDs, dates, timestamps and enums travel as text;
/// booleans as integer 0/1; Postgres arrays as JSON text.
let reloSchema = Schema(tables: [
    Table(name: "moves", columns: [
        .text("user_id"),
        .text("name"),
        .text("origin_address"),
        .text("destination_address"),
        .text("move_date"),
        .text("start_date"),
        .integer("is_active"),
        .text("created_at"),
        .text("updated_at"),
        .text("deleted_at"),
    ]),
    Table(name: "expenses", columns: [
        .text("user_id"),
        .text("move_id"),
        .integer("amount_cents"),
        .text("currency"),
        .text("occurred_on"),
        .text("merchant"),
        .text("category_id"),
        .text("payer"),
        .integer("missing_receipt"),
        .text("tax_tags"),
        .text("extraction_source"),
        .text("notes"),
        .text("created_at"),
        .text("updated_at"),
        .text("deleted_at"),
    ]),
])
