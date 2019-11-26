//
//  AddMembers.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/6/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import UIKit
import PKHUD
import VirgilSDK

class AddMembersViewController: ViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIBarButtonItem!

    private var channels: [Channel] = []

    private var selected: [Channel] = [] {
        didSet {
            self.addButton.isEnabled = !self.selected.isEmpty
        }
    }

    public var dataSource: DataSource!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupTableView()

        Notifications.removeObservers(self)
        Notifications.observe(self, for: .channelDeleted, task: self.popToRoot)
        Notifications.observe(self, for: .messageAddedToCurrentChannel, task: self.reloadTableView)
    }

    deinit {
        Notifications.removeObservers(self)
    }

    private func setupTableView() {
        let chatListCellNib = UINib(nibName: ChooseMembersCell.name, bundle: Bundle.main)
        self.tableView.register(chatListCellNib, forCellReuseIdentifier: ChooseMembersCell.name)

        self.tableView.rowHeight = 60
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.dataSource = self

        self.reloadTableView()
    }

    @objc private func reloadTableView() {
        self.channels = CoreData.shared.getSingleChannels()

        self.channels = self.channels.filter { channel in
            !CoreData.shared.currentChannel!.cards.contains { card in
                channel.cards.first?.identity == card.identity
            }
        }

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    @IBAction func addTapped(_ sender: Any) {
        let add = self.selected.map { $0.name }

        guard
            !add.isEmpty,
            self.checkReachability(),
            Configurator.isUpdated
        else {
            return
        }

        HUD.show(.progress)

//        ChatsManager.addMembers(add, dataSource: self.dataSource).start { _, error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    HUD.hide()
//                    self.alert(error)
//                } else {
//                    HUD.flash(.success)
//                    self.navigationController?.popViewController(animated: true)
//                }
//            }
//        }
    }
}

extension AddMembersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.channels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChooseMembersCell.name) as! ChooseMembersCell

        cell.tag = indexPath.row
        cell.delegate = self

        cell.configure(with: self.channels)

        return cell
    }
}

extension AddMembersViewController: CellTapDelegate {
    func didTapOn(_ cell: UITableViewCell) {
        if let cell = cell as? ChooseMembersCell {
            let channel = self.channels[cell.tag]

            if cell.isMember {
                self.selected.append(channel)
            } else {
                self.selected = self.selected.filter { $0 != channel }
            }
        }
    }
}

