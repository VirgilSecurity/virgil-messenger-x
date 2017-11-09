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
        
        /*
        // Do any additional setup after loading the view, typically from a nib.
        let file = "file.txt" //this is the file. we will write to and read from it
        
        //let text = "some text" //just a text
        //let text0 = "sd"
        let data = "some text".data(using: .utf8)
        let data1 = "sd".data(using: .utf8)
            
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = dir.appendingPathComponent(file)
            
            //writing
            do {
                let fileHandle = try FileHandle.init(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                fileHandle.write(data!)
                    //fileHandle.closeFile()
                fileHandle.seekToEndOfFile()
                fileHandle.write(data1!)
                fileHandle.closeFile()

                //try text.write(to: fileURL, atomically: false, encoding: .utf8)
                //try text0.write(to: fileURL, atomically: false, encoding: .utf8)
                Log.debug("file was written")
            }
            catch {Log.error("file writting")}
            
            //reading
            do {
                let text2 = try String(contentsOf: fileURL, encoding: .utf8)
                Log.debug("file was read: \(text2)")
                
                let text3 = try String(contentsOf: fileURL, encoding: .utf8)
                Log.debug("file was read: \(text3)")
            }
            catch {Log.error("file reading")}
        } else {
            Log.error("directory")
        }
        */
        
        UIApplication.shared.delegate?.window??.rootViewController = UIStoryboard(name: RegistrationViewController.name, bundle: Bundle.main).instantiateInitialViewController()!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

