//
//  ViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    var topBarHeight: CGFloat {
        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = self.navigationController?.navigationBar.frame.height ?? 0.0
        let offset = self.navigationController?.navigationBar.frame.origin.y ?? 0.0

        return statusBarHeight + navBarHeight + offset
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    deinit {
        Log.debug(self.description)
    }

    struct Cell {
        enum Identifier: String, CaseIterable {
            case regular
            case detail

            func register(in tableView: UITableView) {
                let type: UITableViewCell.Type
                switch self {
                case .regular:
                    type = UITableViewCell.self
                case .detail:
                    type = DetailTableViewCell.self
                }

                tableView.register(
                    type,
                    forCellReuseIdentifier: self.rawValue
                )
            }
        }

        let identifier: Identifier
        let action: (() -> Void)?
        let configure: ((UITableViewCell) -> Void)

        func dequeue(from tableView: UITableView, for indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: identifier.rawValue,
                for: indexPath
            )

            cell.accessoryType = .none
            cell.backgroundColor = .appThemeBackgroundColor

            let colorView = UIView()
            colorView.backgroundColor = .appThemeForegroundColor
            cell.selectedBackgroundView = colorView

            configure(cell)

            return cell
        }

        static func registerCells(in tableView: UITableView) {
            Identifier.allCases.forEach {
                $0.register(in: tableView)
            }
        }
    }
}
