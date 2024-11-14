//
//  ProfileViewController.swift
//  Packsync
//
//  Created by Jessica on 10/24/24.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage
import PhotosUI
import FirebaseFirestore

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {

    private let profileView = ProfileView()
    private var isEditingProfile = false

    var handleAuth: AuthStateDidChangeListenerHandle?
    var currentUser: FirebaseAuth.User?
    private let firestore = Firestore.firestore()  // Firestore instance for accessing Firestore

    override func loadView() {
        view = profileView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupActions()
        loadUserProfile()
        
        title = "PROFILE DETAIL"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            style: .plain,
            target: self,
            action: #selector(toggleEditProfile)
        )
        
        Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            self?.handleAuthStateChange(user: user)
        }
    }

    func handleAuthStateChange(user: FirebaseAuth.User?) {
        if let user = user {
            currentUser = user
            postLogin()
        } else {
            currentUser = nil
            postLogout()
        }
    }
    
    func postLogin() {
        let displayName = currentUser?.displayName ?? ""
        let email = currentUser?.email ?? ""
        
        profileView.nameTextField.text = "Name: " + displayName
        profileView.emailTextField.text = "Email: " + email

        loadUserProfile()
    }

    func postLogout() {
        profileView.nameTextField.text = "<pls login first>"
        profileView.emailTextField.text = ""
        profileView.profileImageView.image = nil  // Clear profile image on logout
    }

    private func setupActions() {
        profileView.configurePhotoButton(target: self, action: #selector(showPhotoOptions))
    }

    @objc private func toggleEditProfile() {
        isEditingProfile.toggle()

        title = isEditingProfile ? "EDIT PROFILE" : "Profile"
        
        navigationItem.rightBarButtonItem?.title = isEditingProfile ? "Save" : "Edit"
        
        if isEditingProfile {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Cancel",
                style: .plain,
                target: self,
                action: #selector(cancelEditing)
            )
        } else {
            navigationItem.leftBarButtonItem = nil
        }

        toggleEditing(isEditingProfile)
        
        if !isEditingProfile {
            saveProfileChanges()
        }
    }

    @objc private func cancelEditing() {
        isEditingProfile = false
        
        navigationItem.rightBarButtonItem?.title = "Edit"
        navigationItem.leftBarButtonItem = nil
        
        toggleEditing(false)
        
        loadUserProfile()
    }

    private func toggleEditing(_ enable: Bool) {
        profileView.nameTextField.isUserInteractionEnabled = enable
        profileView.emailTextField.isUserInteractionEnabled = enable
        
        profileView.togglePhotoEditing(enabled: enable)
        
        if enable {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showPhotoOptions))
            profileView.profileImageView.addGestureRecognizer(tapGesture)
            profileView.profileImageView.isUserInteractionEnabled = true
        } else {
            profileView.profileImageView.gestureRecognizers?.forEach { profileView.profileImageView.removeGestureRecognizer($0) }
            profileView.profileImageView.isUserInteractionEnabled = false
        }
    }

    private func loadUserProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        // Access Firestore to retrieve the profile image URL
        firestore.collection("users").document(userID).getDocument { snapshot, error in
            if let error = error {
                print("Error loading user profile: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data() else { return }
            self.profileView.nameTextField.text = data["displayName"] as? String ?? self.profileView.nameTextField.text
            self.profileView.emailTextField.text = data["email"] as? String ?? self.profileView.emailTextField.text
            if let profileImageUrl = data["profileImageUrl"] as? String {
                self.loadProfileImage(urlString: profileImageUrl)
            }
        }
    }

    private func saveProfileChanges() {
        guard let userID = Auth.auth().currentUser?.uid,
              let name = profileView.nameTextField.text,
              let email = profileView.emailTextField.text else { return }

        let ref = firestore.collection("users").document(userID)
        ref.setData(["displayName": name, "email": email], merge: true)
    }

    private func loadProfileImage(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.profileView.profileImageView.image = image
                self.profileView.buttonTakePhoto.setImage(nil, for: .normal)
            }
        }.resume()
    }

    @objc private func showPhotoOptions() {
        let actionSheet = UIAlertController(title: "Select Photo", message: "Choose a source", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.pickUsingCamera()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Gallery", style: .default, handler: { _ in
            self.pickPhotoFromGallery()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true, completion: nil)
    }

    private func pickUsingCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.allowsEditing = true
            present(picker, animated: true, completion: nil)
        } else {
            showAlert("Camera not available")
        }
    }

    private func pickPhotoFromGallery() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        if let itemProvider = results.first?.itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
                DispatchQueue.main.async {
                    if let selectedImage = image as? UIImage {
                        self?.profileView.profileImageView.image = selectedImage
                        self?.uploadProfileImage(selectedImage)
                        self?.profileView.buttonTakePhoto.setImage(nil, for: .normal)
                    }
                }
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[.editedImage] as? UIImage {
            profileView.profileImageView.image = selectedImage
            uploadProfileImage(selectedImage)
            profileView.buttonTakePhoto.setImage(nil, for: .normal)
        }
        picker.dismiss(animated: true, completion: nil)
    }

    private func uploadProfileImage(_ image: UIImage) {
        guard let userID = Auth.auth().currentUser?.uid, let imageData = image.jpegData(compressionQuality: 0.75) else { return }
        let storageRef = Storage.storage().reference().child("profile_images").child("\(userID).jpg")
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Failed to upload image: \(error.localizedDescription)")
                return
            }
            storageRef.downloadURL { url, error in
                guard let profileImageUrl = url?.absoluteString else {
                    print("Failed to retrieve download URL: \(error?.localizedDescription ?? "No error")")
                    return
                }
                // Save the URL to Firestore
                self.firestore.collection("users").document(userID).setData(["profileImageUrl": profileImageUrl], merge: true)
            }
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
}
