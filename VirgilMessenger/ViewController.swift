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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.delegate?.window??.rootViewController = UIStoryboard(name: RegistrationViewController.name, bundle: Bundle.main).instantiateInitialViewController()!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

