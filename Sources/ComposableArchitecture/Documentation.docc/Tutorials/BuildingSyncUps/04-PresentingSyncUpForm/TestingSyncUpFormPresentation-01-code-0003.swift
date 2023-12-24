import ComposableArchitecture
import SyncUps
import XCTest

class SyncUpsListTests: XCTestCase {
  func testAddSyncUp() async {
    let store = TestStore(initialState: SyncupsList.State()) {
      SyncUpsList()
    }

    await store.send(.addButtonTapped) {
      $0.addSyncUp = SyncUpForm.State(syncUp: SyncUp(id: SyncUp.ID()))
    }
  }

  func testDeletion() async {
    // ...
  }
}
