import "ToucanDAO"

/// Get the complete DAO configuration information
/// Returns: ConfigurationInfo struct containing all config values and state
access(all)
fun main(): ToucanDAO.ConfigurationInfo {
    return ToucanDAO.getConfiguration()
}

