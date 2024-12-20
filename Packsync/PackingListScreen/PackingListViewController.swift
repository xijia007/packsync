//
//  PackingListViewController.swift
//  Packsync
//
//  Created by Xi Jia on 11/8/24.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class PackingListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, PackingListViewControllerDelegate, EditPackingItemViewControllerDelegate {
    
    let packingListView = PackingListView()
    var travel: Travel?
    var packingItems: [PackingItem] = []
    
    override func loadView() {
        view = packingListView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Packing List"
        
        packingListView.tableViewPackingList.delegate = self
        packingListView.tableViewPackingList.dataSource = self
        
        packingListView.buttonAddPackingItem.addTarget(self, action: #selector(addPackingItemButtonTapped), for: .touchUpInside)
        
        fetchPackingItems()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchPackingItems()
    }
    
    @objc func addPackingItemButtonTapped() {
        let addPackingItemVC = AddPackingItemViewController()
        addPackingItemVC.travel = self.travel
        addPackingItemVC.delegate = self
        let navController = UINavigationController(rootViewController: addPackingItemVC)
        present(navController, animated: true, completion: nil)
    }

    func fetchPackingItems() {
        guard let travel = travel else { return }

        let db = Firestore.firestore()
        db.collection("trips").document(travel.id).collection("packingItems")
            .whereField("creatorId", isEqualTo: travel.creatorId)
            .whereField("travelId", isEqualTo: travel.id)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
               
                self?.packingItems = documents.compactMap { queryDocumentSnapshot in
                    let data = queryDocumentSnapshot.data()
                    let id = queryDocumentSnapshot.documentID
                    let name = data["name"] as? String ?? ""
                    let itemNumber = data["itemNumber"] as? String ?? ""
                    let isPacked = data["isPacked"] as? Bool ?? false
                    let isPackedBy = data["isPackedBy"] as? String

                    return PackingItem(id: id, creatorId: travel.creatorId, travelId: travel.id, name: name, isPacked: isPacked, isPackedBy: isPackedBy, itemNumber: itemNumber)
                }
                
                DispatchQueue.main.async {
                    self?.packingListView.tableViewPackingList.reloadData()
                }
            }
    }
    
    
    @objc func checkboxTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < packingItems.count else {
            print("Error: Invalid index")
            return
        }
        
        packingItems[index].isPacked.toggle()
        sender.isSelected = packingItems[index].isPacked
        
        // Update the item in Firestore
        guard let travel = travel else {
            print("Error: Travel object is nil")
            return
        }
        
        let db = Firestore.firestore()
        let id = packingItems[index].id
        let currentUser = Auth.auth().currentUser
        let displayName = currentUser?.displayName ?? "Unknown User"
        let updateData: [String: Any] = [
            "isPacked": packingItems[index].isPacked,
            "isPackedBy": packingItems[index].isPacked ? displayName : NSNull()
        ]
        
        db.collection("trips").document(travel.id).collection("packingItems").document(id).updateData(updateData) { [weak self] error in
            if let error = error {
                print("Error updating document: \(error)")
                // Revert the change if the update fails
                DispatchQueue.main.async {
                    self?.packingItems[index].isPacked.toggle()
                    sender.isSelected = self?.packingItems[index].isPacked ?? false
                }
            } else {
                print("Document successfully updated")
                // Update the local packingItems array
                self?.packingItems[index].isPackedBy = self?.packingItems[index].isPacked == true ? displayName : nil
                // Refresh the UI
                DispatchQueue.main.async {
                    self?.packingListView.tableViewPackingList.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                }
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return packingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PackingItemCell", for: indexPath) as? PackingItemCell else {
            fatalError("Unable to dequeue PackingItemCell")
        }
        
        let item = packingItems[indexPath.row]
        cell.configure(with: item)
        cell.checkboxButton.tag = indexPath.row
        cell.checkboxButton.addTarget(self, action: #selector(checkboxTapped(_:)), for: .touchUpInside)
        
        return cell
    }
    
    // MARK: - PackingListViewControllerDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = packingItems[indexPath.row]
        let editPackingItemVC = EditPackingItemViewController()
        editPackingItemVC.packingItem = item
        editPackingItemVC.delegate = self
        let navController = UINavigationController(rootViewController: editPackingItemVC)
        present(navController, animated: true, completion: nil)
    }



    func didAddPackingItem(_ item: PackingItem) {
        packingListView.tableViewPackingList.reloadData()
    }
    

    // MARK: - EditPackingItemViewControllerDelegate
    
    func didUpdatePackingItem(_ item: PackingItem) {
        if let index = packingItems.firstIndex(where: { $0.id == item.id }) {
            packingItems[index] = item
            packingListView.tableViewPackingList.reloadData()
        }
    }

    func didDeletePackingItem(_ item: PackingItem) {
        if let index = packingItems.firstIndex(where: { $0.id == item.id }) {
            packingItems.remove(at: index)
            packingListView.tableViewPackingList.reloadData()
        }
    }
}
