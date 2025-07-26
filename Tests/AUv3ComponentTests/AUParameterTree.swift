// Copyright © 2020, 2024 Brad Howes. All rights reserved.

import AudioToolbox
import Numerics

@testable import AUv3Component
import Testing

fileprivate class MockProvider : ParameterAddressProvider {
  var parameterAddress: AUParameterAddress = 123
}

private final class Context {
  let params: [AUParameter]
  let tree: AUParameterTree

  init() {
    params = [AUParameterTree.createParameter(withIdentifier: "First", name: "First Name", address: 123,
                                              min: 0.0, max: 100.0, unit: .generic, unitName: nil,
                                              flags: [.flag_IsReadable], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "Second", name: "Second Name", address: 456,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_IsReadable], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "Squared", name: "Squared", address: 1,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_DisplaySquared], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "SquareRoot", name: "SquareRoot", address: 2,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_DisplaySquareRoot], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "Cubed", name: "Cubed", address: 3,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_DisplayCubed], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "CubeRoot", name: "CubeRoot", address: 4,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_DisplayCubeRoot], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "Logarithmic", name: "Logarithmic", address: 5,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_DisplayLogarithmic], valueStrings: nil,
                                              dependentParameters: nil),
              AUParameterTree.createParameter(withIdentifier: "Exponential", name: "Exponential", address: 6,
                                              min: 10.0, max: 200.0, unit: .generic, unitName: nil,
                                              flags: [.flag_DisplayExponential], valueStrings: nil,
                                              dependentParameters: nil),
    ]
    tree = AUParameterTree.createTree(withChildren: params)
  }

  var notifier: ((AUParameterAddress, AUValue) -> Void)?

  func processParameter(address: AUParameterAddress, value: AUValue) {
    notifier?(address, value)
  }
}

@Test func accessByParameterAddressProvider() {
  let ctx = Context()
  #expect(ctx.tree.parameter(source: MockProvider()) == ctx.params[0])
}

@Test func testParameterRange() {
  let ctx = Context()
  #expect(ctx.params[0].range == 0.0...100.0)
  #expect(ctx.params[1].range == 10.0...200.0)
}

@Test func testParametricValue() {
  #expect(ParametricValue(0.1).value == 0.1)
  #expect(ParametricValue(-0.1).value == 0.0)
  #expect(ParametricValue(1.0).value == 1.0)
  #expect(ParametricValue(1.1).value == 1.0)
}

@Test func testParametricSquaredTransforms() {
  let ctx = Context()
  let value = ParametricValue(0.5)
  let param = ctx.params[2]
  param.setParametricValue(value)
  #expect(param.value == 144.35028)
  #expect(param.parametricValue.value.isApproximatelyEqual(to: 0.5))
}

@Test func testParametricSquareRootTransforms() {
  let ctx = Context()
  let value = ParametricValue(0.5)
  let param = ctx.params[3]
  param.setParametricValue(value)
  #expect(param.value == 57.5)
  #expect(param.parametricValue.value == 0.5)
}

@Test func testParametricCubedTransforms() {
  let ctx = Context()
  let param = ctx.params[4]
  param.setParametricValue(0.5)
  #expect(param.value == 160.8031)
  #expect(param.parametricValue.value == 0.5)
}

@Test func testParametricCubeRootTransforms() {
  let ctx = Context()
  let param = ctx.params[5]
  param.setParametricValue(0.5)
  #expect(param.value == 33.75)
  #expect(param.parametricValue.value == 0.5)
}

@Test func testParametricLogarithmicTransforms() {
  let ctx = Context()
  let param = ctx.params[6]
  param.setParametricValue(0.5)
  #expect(param.value == 55.648083)
  #expect(param.parametricValue.value == 0.5106643)
}

@Test func testParametricExponentialTransforms() {
  let ctx = Context()
  let param = ctx.params[7]
  param.setParametricValue(0.5)
  #expect(param.value == 151.97214)
  #expect(param.parametricValue.value == 0.50972825)
}

@Test func testObservation() async throws {
  let ctx = Context()
  let (stream, continuation) = AsyncStream<Void>.makeStream()
  await confirmation { confirmed in
    let token = ctx.tree.token { address, value in
      #expect(address == 123)
      #expect(value == 0.5)
      confirmed()
      continuation.yield()
    }

    ctx.params[0].setValue(0.5, originator: nil)

    var iterator = stream.makeAsyncIterator()
    await iterator.next()

    ctx.tree.removeParameterObserver(token)
  }
}

@Test func testObservationNonActor() async throws {
  let ctx = Context()
  let (stream, continuation) = AsyncStream<Void>.makeStream()
  await confirmation { confirmed in
    let token = ctx.tree.token(byAddingParameterObserver: ctx.processParameter(address:value:))

    ctx.notifier = { address, value in
      #expect(address == 123)
      #expect(value == 0.5)
      confirmed()
      continuation.yield()
    }

    ctx.params[0].setValue(0.5, originator: nil)

    var iterator = stream.makeAsyncIterator()
    await iterator.next()

    ctx.tree.removeParameterObserver(token)
  }
}

@Test func dynamicMemberLookup() async throws {
  let group1 = AUParameterTree.createGroup(
    withIdentifier: "group1",
    name: "Group 1",
    children: [
      AUParameterTree.createParameter(
        withIdentifier: "first",
        name: "First Name",
        address: 1001,
        min: 0.0,
        max: 100.0,
        unit: .generic,
        unitName: nil,
        flags: [.flag_IsReadable],
        valueStrings: nil,
        dependentParameters: nil
      ),
      AUParameterTree.createParameter(
        withIdentifier: "second",
        name: "Second Name",
        address: 1002,
        min: 10.0,
        max: 200.0,
        unit: .generic,
        unitName: nil,
        flags: [.flag_IsReadable],
        valueStrings: nil,
        dependentParameters: nil
      ),
    ]
  )
  let group2 = AUParameterTree.createGroup(
    withIdentifier: "group2",
    name: "Group 2",
    children: [
      AUParameterTree.createParameter(
        withIdentifier: "third",
        name: "Third Name",
        address: 2001,
        min: 0.0,
        max: 100.0,
        unit: .generic,
        unitName: nil,
        flags: [.flag_IsReadable],
        valueStrings: nil,
        dependentParameters: nil
      ),
      AUParameterTree.createParameter(
        withIdentifier: "fourth",
        name: "Fourth Name",
        address: 2002,
        min: 10.0,
        max: 200.0,
        unit: .generic,
        unitName: nil,
        flags: [.flag_IsReadable],
        valueStrings: nil,
        dependentParameters: nil
      ),
    ]
  )
  let root = AUParameterTree.createGroup(
    withIdentifier: "root",
    name: "Root",
    children: [
      group1,
      group2
    ]
  )

  let tree = AUParameterTree.createTree(withChildren: [root])
  let group = tree.dynamicMemberLookup.root?.group1
  #expect(group?.group != nil)
  #expect(group?.parameter == nil)

  let first = tree.dynamicMemberLookup.root?.group1?.first
  #expect(first != nil)
  var param = first?.parameter
  #expect(param != nil)
  #expect(param?.address == 1001)

  let second = tree.dynamicMemberLookup.root?.group1?.second
  #expect(second != nil)
  param = second?.parameter
  #expect(param != nil)
  #expect(param?.address == 1002)

  let third = tree.dynamicMemberLookup.root?.group2?.third
  #expect(third != nil)
  param = third?.parameter
  #expect(param != nil)
  #expect(param?.address == 2001)

  let fourth = tree.dynamicMemberLookup.root?.group2?.fourth
  #expect(fourth != nil)
  param = fourth?.parameter
  #expect(param != nil)
  #expect(param?.address == 2002)

  #expect(fourth?.group == nil)
  #expect(fourth?.blahblah == nil)

  let unknown = tree.dynamicMemberLookup.blah
  #expect(unknown == nil)
}
