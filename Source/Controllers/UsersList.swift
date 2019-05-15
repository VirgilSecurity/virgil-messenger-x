//
//  UsersList.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 4/15/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit

class UsersListViewController: UITableViewController {
    public var users: [Channel] = []

    public var cellTapDelegate: CellTapDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.rowHeight = 60
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self
    }

    override func viewWillAppear(_ animated: Bool) {
        self.tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UsersListCell.name) as! UsersListCell

        cell.tag = self.users.count - indexPath.row - 1
        cell.delegate = self.cellTapDelegate

        cell.configure(with: self.users)

        return cell
    }
}
