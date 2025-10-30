import "ToucanDAO"

/// Get the total number of members in the DAO
access(all)
fun main(): UInt64 {
    return ToucanDAO.getMemberCount()
}

