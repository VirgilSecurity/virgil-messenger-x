//
//  CallableController.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 5/6/20.
//  Copyright © 2020 VirgilSecurity. All rights reserved.
//

import UIKit

class CallableController: ViewController {
    weak private var callViewController: CallViewController?

    // lazy weak variables are not allowed in swift
    private var lazyCallViewController: CallViewController {
        let result: CallViewController

        if let existing = self.callViewController {
            result = existing
        }
        else {
            let storyboard = UIStoryboard(name: "Call", bundle: nil)
            let viewController = storyboard.instantiateViewController(withIdentifier: "Call")

            viewController.modalPresentationStyle = .fullScreen
            viewController.modalTransitionStyle = .crossDissolve

            guard let callViewController = viewController as? CallViewController else {
                fatalError("ViewController with identifier 'Call' is not of type CallViewController")
            }

            self.callViewController = callViewController

            result = callViewController
        }

        return result
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        CallManager.shared.delegate = self

        // TODO: Fix check on multi calls
        if let call = CallManager.shared.calls.first {
            self.setupCallViewController(with: call)
        }
    }

    private func setupCallViewController(with call: Call) {
        DispatchQueue.main.async {
            let callViewController = self.lazyCallViewController

            callViewController.addCall(call: call)

            // TODO: check if can be replaced to .isBeingPresented
            if callViewController.viewIfLoaded?.window == nil {
                self.present(callViewController, animated: true, completion: nil)
            }
        }
    }
}

extension CallableController: CallManagerDelegate {
    func callManager(_ callManager: CallManager, didAddCall call: Call) {
        self.setupCallViewController(with: call)
    }

    func callManager(_ callManager: CallManager, didRemoveCall call: Call) {
        self.callViewController?.removeCall(call: call)
    }

    func callManager(_ callManager: CallManager, didFail error: Error) {
        DispatchQueue.main.async {
            self.alert(error)
        }
    }

    func callManager(_ callManager: CallManager, didFailCall call: Call, error: Error) {
    }
}
