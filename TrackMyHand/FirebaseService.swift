//
//  FirebaseService.swift
//  TrackMyHand
//
//  Created by Laksh Bharani on 14/12/24.
//

import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    // Fetch all users
    func fetchUsers(completion: @escaping ([User]) -> Void) {
        db.collection("users")
            .order(by: "totalProfit", descending: true)
            .getDocuments { (snapshot, error) in
            guard let documents = snapshot?.documents else {
                print("Error fetching users: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            let users = documents.compactMap { try? $0.data(as: User.self) }
            completion(users)
        }
    }
    
    // create a user for the first time using id
    func createUser(id: String, completion: @escaping (Result<User, Error>) -> Void) {
        do {
            let user = User(id: id, totalProfit: 0, gamesPlayed: 0)
            let _ = try db.collection("users").document(user.id).setData(from: user)
            
        } catch _ {
        }
    }
    
    // Fetch only top 3 users with most profit
    func fetchLeaderboard(completion: @escaping ([User]) -> Void) {
        db.collection("users")
            .order(by: "totalProfit", descending: true)
            .limit(to: 3)
            .getDocuments { (snapshot, error) in
            guard let documents = snapshot?.documents else {
                print("Error fetching users: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            let users = documents.compactMap { try? $0.data(as: User.self) }
            completion(users)
        }
    }
    
    // Fetch all games
    func fetchGames(limit: Int, completion: @escaping ([Game]) -> Void) {
        db.collection("games")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments { (snapshot, error) in
                guard let documents = snapshot?.documents else {
                    print("Error fetching games: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                let games = documents.compactMap { try? $0.data(as: Game.self) }
                completion(games)
            }
    }
    
    // Add a new game
    // Function to add a new game
    func createGame(game: Game, completion: @escaping (Error?) -> Void) {
        do {
            let _ = try db.collection("games").document(game.id).setData(from: game)
            // Update each user's stats
            for player in game.players {
                updateUserStatsOnGameStart(userId: player.id, profit: player.profit) { _ in }
            }
            completion(nil)
        } catch let error {
            completion(error)
        }
    }
    
    // Update user stats before a game -> to prepare db to handle transaction changes
    func updateUserStatsOnGameStart(userId: String, profit: Double, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { (document, error) in
            if let error = error {
                completion(error)
                return
            }
            
            if let document = document, document.exists {
                // Update existing document
                userRef.updateData([
                    "totalProfit": FieldValue.increment(profit),
                    "gamesPlayed": FieldValue.increment(1.0)
                ]) { error in
                    completion(error)
                }
            } else {
                // Set data for a new document
                userRef.setData([
                    "id" : userId,
                    "totalProfit": profit,
                    "gamesPlayed": 1.0
                ]) { error in
                    completion(error)
                }
            }
        }
    }
}