import CoreModels
import Foundation

/// The selectable destinations in the sidebar. Smart lists come first, then
/// user groups.
enum SidebarItem: Hashable {
    case all
    case favorites
    case recents
    case ungrouped
    case group(GroupID)
}
