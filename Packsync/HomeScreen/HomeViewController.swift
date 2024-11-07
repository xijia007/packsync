//
//  HomeViewController.swift
//  Packsync
//
//  Created by 许多 on 10/24/24.
//

import UIKit

class HomeViewController: UIViewController {
    private let homeView = HomeView()

    override func loadView() {
        view = homeView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home Page"
        setupActions()
    }
    
    private func setupActions() {
        homeView.getStartedButton.addTarget(self, action: #selector(handleGetStarted), for: .touchUpInside)
    }
    
    @objc private func handleGetStarted() {
        // Action to perform when the "Get Started" button is tapped
        let loginVC = LoginViewController()
        navigationController?.pushViewController(loginVC, animated: true)
    }
}

