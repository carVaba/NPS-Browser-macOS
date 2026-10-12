import Cocoa

extension NSTableViewDiffableDataSource {
    // Waits until the table shows the snapshot.
    func show(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animated: Bool) async {
        await withCheckedContinuation { continuation in
            apply(snapshot, animatingDifferences: animated) {
                continuation.resume()
            }
        }
    }
}
