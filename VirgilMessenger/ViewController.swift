//
//  ViewController.swift
//  VirgilMessenger
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.showChat()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func showChat() {
        self.performSegue(withIdentifier: "showChat", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        var initialCount = 0
        let pageSize = 50
        
        var dataSource: FakeDataSource!
        if segue.identifier == "showChat" {
            initialCount = 10000
        } else {
            assert(false, "segue not handled!")
        }
        
        let chatController = { () -> DemoChatViewController? in
            if let controller = segue.destination as? DemoChatViewController {
                return controller
            }
            return nil
            }()!
        
        if dataSource == nil {
            dataSource = FakeDataSource(count: initialCount, pageSize: pageSize)
        }
        chatController.dataSource = dataSource
        chatController.messageSender = dataSource.messageSender
    }
}

