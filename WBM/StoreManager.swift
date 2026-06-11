//
//  StoreManager.swift
//  WBM
//
//  Created by Cooper Lindquist on 3/16/26.
//

import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
class StoreManager: ObservableObject {

    @Published var products: [Product] = []

    let productIDs = [
        "diamonds_50",
        "diamonds_200",
        "diamonds_500"
    ]

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products:", error)
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {

            case .success(let verification):

                switch verification {

                case .verified(_):
                    giveDiamonds(for: product.id)

                case .unverified:
                    print("Purchase not verified")
                }

            default:
                break
            }

        } catch {
            print("Purchase failed:", error)
        }
    }

    private func giveDiamonds(for productID: String) {

        guard let uid = Auth.auth().currentUser?.uid else { return }

        let diamondsToAdd: Int

        switch productID {
        case "diamonds_50":
            diamondsToAdd = 50
        case "diamonds_200":
            diamondsToAdd = 200
        case "diamonds_500":
            diamondsToAdd = 500
        default:
            return
        }

        let userRef = Firestore.firestore().collection("users").document(uid)

        userRef.updateData([
            "diamonds": FieldValue.increment(Int64(diamondsToAdd))
        ])
    }
}
