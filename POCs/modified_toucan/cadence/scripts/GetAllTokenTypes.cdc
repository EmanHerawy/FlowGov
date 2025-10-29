import "ToucanDAO"

/// Get all registered token types
/// Returns: Dictionary mapping token type ID to type identifier string
access(all)
fun main(): {UInt64: String} {
    return ToucanDAO.getAllTokenTypes()
}

