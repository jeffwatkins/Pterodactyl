//
//  ViewController.swift
//  PterodactylExample
//
//  Created by Matt Stanford on 3/17/20.
//  Copyright © 2020 Matt Stanford. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var defaultsValueLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        let userDefaults = UserDefaults.standard
        if let testValue = userDefaults.string(forKey: "Test") {
            self.defaultsValueLabel?.text = testValue
        } else {
            self.defaultsValueLabel?.text = "MISSING VALUE"
            self.defaultsValueLabel?.textColor = .red
        }
    }

}

