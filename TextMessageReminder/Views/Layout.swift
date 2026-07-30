import CoreGraphics

/// One spacing scale for the whole app, on the 4pt grid iOS itself uses.
/// Views reach for these instead of inventing a number per stack.
enum Layout {

    /// Between tightly coupled text, e.g. a title and the line under it.
    static let tight: CGFloat = 4

    /// Between the elements of a single component.
    static let snug: CGFloat = 8

    /// Between a block of content and a control sitting beside it.
    static let regular: CGFloat = 12

    /// A grouped list row's content inset, matching UIKit's horizontal one and
    /// used on all four sides so a row's margins are even.
    static let gutter: CGFloat = 16

    /// A contact avatar, sized like the ones in Messages' conversation list.
    static let avatarDiameter: CGFloat = 40

    /// The square a glyph sits in inside a circular icon button. With the bordered
    /// style's padding around it this lands on a ~32pt circle, the size iOS gives
    /// the round buttons it tucks into list rows.
    static let iconButtonGlyph: CGFloat = 24

    /// `TextEditor` draws its text 5pt inside its own bounds. Subtracting that
    /// from the row's insets lines the message up with every other row in the
    /// form instead of sitting 5pt proud of them.
    static let textEditorTextInset: CGFloat = 5

    /// The matching vertical offset, used to seat the placeholder on the first line.
    static let textEditorTopInset: CGFloat = 8

    /// Roughly four lines of body text — enough to write in without a scroll gutter.
    static let messageEditorMinHeight: CGFloat = 96
}
