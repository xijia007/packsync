//
//  TravelListViewController.swift
//  Packsync
//
//  Created by 许多 on 10/24/24.
//
import UIKit

class TravelListViewController: UIViewController {
    
    let travelListView = TravelListView()
    
    override func loadView() {
        view = travelListView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "TravelCrew"
        view.backgroundColor = .white
        
        // Add A New Traver button navigation to the AddANewTraverl Screen
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTravelButtonTapped))
        
        //MARK: tapping the floating add login button...
        travelListView.floatingButtonLogin.addTarget(self, action: #selector(addLoginButtonTapped), for: .touchUpInside)
        
        travelListView.getStartedButton.addTarget(self, action: #selector(handleGetStarted), for: .touchUpInside)
           
    }
    
    @objc func addTravelButtonTapped() {
        let addTravelViewController = AddANewTraverlViewController()
        navigationController?.pushViewController(addTravelViewController, animated: true)
    }

    @objc func addLoginButtonTapped() {
        let addLoginViewController = LoginViewController()
        navigationController?.pushViewController(addLoginViewController, animated: true)
    }
    
    @objc func handleGetStarted() {
        // Action to perform when the "Get Started" button is tapped
        let loginVC = LoginViewController()
        navigationController?.pushViewController(loginVC, animated: true)
    }

}
