//
//  Authentication.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 12/8/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

class AuthenticationViewController: ViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewDidAppear(animated)
    }
}
