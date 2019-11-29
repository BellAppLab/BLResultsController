//
//  BLResultsController+UIKit.swift
//  Example
//
//  Created by André Campana on 29/11/2019.
//  Copyright © 2019 Bell App Lab. All rights reserved.
//

import UIKit

//MARK: - Table Views
public extension ResultsController
{
    /**
      Bind the `ResultsController` changes to a `UITableView`.

      - parameters:
        - tableView:    the table view you want to be driven by this controller.
        - animation:    the `UITableView.RowAnimation` you want applied to the changes in the table view. Defaults to `.automatic`.
    */
    func bind(to tableView: UITableView,
              with animation: UITableView.RowAnimation = .automatic)
    {
        setChangeCallback { [weak tableView] change in
            guard let tableView = tableView else { return }
            switch change {
            case .reload(_):
                tableView.reloadData()
            case .sectionUpdate(_, let insertedSections, let deletedSections):
                tableView.beginUpdates()
                deletedSections.forEach { tableView.deleteSections($0, with: animation) }
                insertedSections.forEach { tableView.insertSections($0, with: animation) }
                tableView.endUpdates()
            case .rowUpdate(_, let insertedItems, let deletedItems, let updatedItems):
                tableView.beginUpdates()
                tableView.deleteRows(at: deletedItems, with: animation)
                tableView.insertRows(at: insertedItems, with: animation)
                tableView.reloadRows(at: updatedItems, with: animation)
                tableView.endUpdates()
            }
        }
    }
}


//MARK: - Collection Views
public extension ResultsController
{
    /**
      Bind the `ResultsController` changes to a `UICollectionView`.

      - parameters:
        - collectionView:    the collection view you want to be driven by this controller.
        - completion:        the completion handler you want to be passed to `collectionView.performBatchUpdates()`. Defaults to `nil`.
    */
    func bind(to collectionView: UICollectionView,
              completion: ((Bool) -> Void)? = nil)
    {
        setChangeCallback { [weak collectionView] change in
            guard let collectionView = collectionView else { return }
            switch change {
            case .reload(_):
                collectionView.reloadData()
            case .sectionUpdate(_, let insertedSections, let deletedSections):
                collectionView.performBatchUpdates({
                    deletedSections.forEach { collectionView.deleteSections($0) }
                    insertedSections.forEach { collectionView.insertSections($0) }
                }, completion: completion)
            case .rowUpdate(_, let insertedItems, let deletedItems, let updatedItems):
                collectionView.performBatchUpdates({
                    collectionView.deleteItems(at: deletedItems)
                    collectionView.insertItems(at: insertedItems)
                    collectionView.reloadItems(at: updatedItems)
                }, completion: completion)
            }
        }
    }
}
