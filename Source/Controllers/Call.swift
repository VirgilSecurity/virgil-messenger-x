//
//  Call.swift
//  VirgilMessenger
//
//  Created by Sergey Seroshtan on 20.03.2020.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class CallViewController: UIViewController {
    
    @IBOutlet weak var calleeLabel : UILabel!
    @IBOutlet weak var callStatusLabel : UILabel!
    @IBOutlet weak var connectionStatusLabel : UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (_) in
            DispatchQueue.main.async {
                self.connectionStatusLabel.text! += "."
            }
        }
    }
    
    @IBAction func endCall(_ sender: Any?) {
        
    }
}
