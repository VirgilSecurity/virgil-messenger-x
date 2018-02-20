//
//  Authentication.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/8/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

class AuthenticationViewController: ViewController {
    @IBOutlet weak var collectionViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        if CoreDataHelper.sharedInstance.accounts.count == 1 {
            collectionViewWidthConstraint.constant = 100
        } else {
            collectionViewWidthConstraint.constant = 225
        }
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewDidAppear(animated)
    }
}
