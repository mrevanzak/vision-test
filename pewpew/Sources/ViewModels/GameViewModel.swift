//
//  GameViewModel.swift
//  pewpew
//
//  Clean ViewModel focused only on state management and coordination
//

import Combine
import SwiftUI

/// Clean ViewModel that coordinates between services and manages game state
final class GameViewModel: GameStateManaging {

  // MARK: - Published Properties
  @Published var score = 0
  @Published var bullets = GameConfiguration.Game.initialBullets
  @Published var isGameOver = false
  @Published var gameStarted = false
  @Published var viewSize: CGSize = .zero
  @Published var selectedCharacter: Character = .sheriffBeq
  @Published var isPaused = false
  @Published var timeRemaining = GameConfiguration.Game.timeLimitSeconds

  // MARK: - Services
  let handDetectionService = HandDetectionService()
  let cameraManager: CameraManager
  let scoreManager = ScoreManager()

  // MARK: - Private Properties
  private var cancellables = Set<AnyCancellable>()
  private var timer: Timer?

  // MARK: - Initialization
  init() {
    self.cameraManager = CameraManager(handDetectionService: handDetectionService)
    setupObservers()
  }

  // MARK: - GameStateManaging Implementation

  func startGame() {
    guard !gameStarted else { return }

    gameStarted = true
    isGameOver = false
    scoreManager.resetScore()
    cameraManager.startSession()
    timeRemaining = GameConfiguration.Game.timeLimitSeconds
    startTimer()
  }

  func stopGame() {
    gameStarted = false
    cameraManager.stopSession()
    stopTimer()
  }

  func gameOver(finalScore: Int? = nil) {
    isGameOver = true
    gameStarted = false
    stopGame()

    if let finalScore = finalScore {
      score = finalScore
    }
  }

  func replayGame() {
    stopGame()

    // Reset state
    scoreManager.resetScore()
    isGameOver = false

    // Start new game
    startGame()
  }

  // MARK: - View Updates

  func updateViewSize(_ size: CGSize) {
    viewSize = size
  }

  // MARK: - Character Selection

  func selectCharacter(_ character: Character) {
    selectedCharacter = character
  }

  // MARK: - Pause/Resume

  func pauseGame() {
    guard gameStarted, !isPaused else { return }
    isPaused = true
    stopTimer()
  }

  func resumeGame() {
    guard isPaused else { return }
    isPaused = false
    startTimer()
  }

  // MARK: - Private Helpers

  private func setupObservers() {
    // Observe score changes
    scoreManager.$currentScore
      .receive(on: DispatchQueue.main)
      .assign(to: \.score, on: self)
      .store(in: &cancellables)

    // Observe bullet changes
    scoreManager.$currentBullets
      .receive(on: DispatchQueue.main)
      .assign(to: \.bullets, on: self)
      .store(in: &cancellables)

    // Monitor for game over when bullets reach zero
    scoreManager.$currentBullets
      .filter { $0 <= 0 }
      .sink { [weak self] _ in
        guard let self = self, self.gameStarted else { return }
        self.gameOver(finalScore: self.score)
      }
      .store(in: &cancellables)

    // Observe camera permission changes to trigger UI updates
    cameraManager.$permissionGranted
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        // Force objectWillChange to trigger UI updates
        self?.objectWillChange.send()
      }
      .store(in: &cancellables)
  }

  // MARK: - Timer Helpers
  private func startTimer() {
    stopTimer()
    guard !isPaused, !isGameOver else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      if self.timeRemaining > 0 {
        self.timeRemaining -= 1
        if self.timeRemaining == 0 {
          self.gameOver(finalScore: self.score)
        }
      }
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }
}
