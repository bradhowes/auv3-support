#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>
#import <functional>
#import <string>
#import <swift/bridging>
#import <vector>

#import <DSPHeaders/BusBuffers.hpp>
#import <DSPHeaders/DelayBuffer.hpp>
#import <DSPHeaders/EventProcessor.hpp>
#import <DSPHeaders/IntrusiveReferenceCounted.hpp>
#import <DSPHeaders/LFO.hpp>
#import <DSPHeaders/Parameters/Bool.hpp>
#import <DSPHeaders/Parameters/Milliseconds.hpp>
#import <DSPHeaders/Parameters/Percentage.hpp>
#import <DSPHeaders/TypeErasedKernel.hpp>

#import "AUv3Demo_ParameterAddress.h"

/**
 The audio processing kernel that generates a "chorus" effect by combining an audio signal with a slightly delayed copy
 of itself. The delay value oscillates at a defined frequency which causes the delayed audio to vary in pitch due to it
 being sped up or slowed down.

 Most of the plumbing and state management is handle by the `EventProcessor` template base class. However, due to
 current limitations in Swift/C++ interoperability base class methods are not visible to Swift, so there are several
 methods in this class that just call to the base class even though this is not necessary in C++-only code.

 An additional base class `IntrusiveReferenceCounted` injects an atomic reference counter that Swift/C++ interop uses to
 manage the lifetime of an instance of this class. When the reference count goes to zero, the instance will be
 automatically freed. We treat the DSPKernel as a reference type in order to allow it to be created outside of the
 audio unit and passed into it during construction.
 */
class AUv3Demo_Kernel :
public DSPHeaders::EventProcessor<AUv3Demo_Kernel>,
public DSPHeaders::IntrusiveReferenceCounted<AUv3Demo_Kernel>
{
public:
  using super = DSPHeaders::EventProcessor<AUv3Demo_Kernel>;
  using refcount = DSPHeaders::IntrusiveReferenceCounted<AUv3Demo_Kernel>;
  friend super;

  inline static constexpr size_t MAX_LFOS{50};

  /**
   Factory method to cread a new Kernel instance. Done this way to make a reference-counted 'class' instance in Swift.

   @param name the name to use for logging inside the kernel
   */
  SWIFT_RETURNS_UNRETAINED static AUv3Demo_Kernel* _Nonnull make(std::string name) noexcept {
    return new AUv3Demo_Kernel(name);
  }

  /**
   Update kernel and buffers to support the given format and channel count. Part of the `AudioRenderer` prototype API.

   @param busCount the number of busses to support
   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* _Nonnull format, AUAudioFrameCount maxFramesToRender) {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
  }

  /**
   Rendering is stopped. Free any allocated render resources.

   Part of the `AudioRenderer` prototype API. Replicated here due to Swift/C++ interop limitation.
   */
  void deallocateRenderResources() { super::deallocateRenderResources(); }

  /**
   @return the bypass state.

   Part of the `AudioRenderer` prototype API. Attempt to satisfy it via `SWIFT_COMPUTED_PROPERTY` generates a Swift
   compiler crash.
   */
  bool getBypass() const noexcept { return super::isBypassed(); }

  /**
   Set the bypass state.

   Part of the `AudioRenderer` prototype API. Attempt to satisfy it via `SWIFT_COMPUTED_PROPERTY` generates a Swift
   compiler crash.

   @param value new bypass value
   */
  void setBypass(bool value) noexcept { super::setBypass(value); }

  /**
   Create a type-erased value used to connect our `processAndRender` to the `AUAudioUnit::internalRenderBlock`
   attribute.

   Part of the `AudioRenderer` prototype API. Attempts to satisfy it via a routine like `getParameterValueObserverBlock`
   below fail due to type mismatch between Swift and C++ that I was unable to overcome. This workaround type erases this
   kernel while still providing access to our `processAndRender` method and its typed parameters. Another C++ class
   takes this value and uses it inside the block returned in the `AUInternalRenderBlock` block obtained from the
   `FilterAudioUnit::internalRenderBlock` attribute.

   @returns `TypeErasedKernel` instance
   */
  DSPHeaders::TypeErasedKernel bridge() {
    using namespace std::placeholders;
    return DSPHeaders::TypeErasedKernel(std::bind(&AUv3Demo_Kernel::processAndRender,
                                                  this,
                                                  _1,
                                                  _2,
                                                  _3,
                                                  _4,
                                                  _5,
                                                  _6));
  }

  /**
   Get the AUParameterTree observer block for fetching values from the tree.

   Part of the `AudioRenderer` prototype API.

   @returns AUImplementorValueObserver block
   */
  AUImplementorValueObserver _Nonnull getParameterValueObserverBlock() {
    return ^(AUParameter* parameter, AUValue value) {
      setParameterValue(parameter.address, value);
    };
  }

  /**
   Get the AUParameterTree provider block for updating parameter values in the tree.

   Part of the `AudioRenderer` prototype API.

   @returns AUImplementorValueProvider block
   */
  AUImplementorValueProvider _Nonnull getParameterValueProviderBlock() {
    return ^AUValue(AUParameter* address) {
      return getParameterValue(address.address);
    };
  }

private:

  /**
   Constructor for new instance. Creation is restricted to the `make` factory method above.

   Set runtime constants and register runtime parameters.

   @param name the name to use for logging inside the kernel
   */
  AUv3Demo_Kernel(std::string name) noexcept :
  super(), refcount(), name_{name}, log_{os_log_create(name_.c_str(), "Kernel")}
  {
    os_log_debug(log_, "constructor");
    registerParameters({gain_});
  }

  AUv3Demo_Kernel(const AUv3Demo_Kernel&) = delete;

  /**
   Entry point for rendering processing of this kernel.
   */
  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {
    auto gain = gain_.frameValue();
    for (auto channelIndex = 0; channelIndex < ins.size(); ++channelIndex) {
      auto in = ins[channelIndex];
      auto out = outs[channelIndex];
      for (auto frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
        out[frameIndex] = in[frameIndex] * gain;
      }
    }
  }

  DSPHeaders::Parameters::Float gain_{AUv3Demo_ParameterAddress::gain};
  std::string name_;
  os_log_t _Nonnull log_;
} SWIFT_SHARED_REFERENCE(_AUv3Demo_Kernel_retain, _AUv3Demo_Kernel_release);

void _AUv3Demo_Kernel_retain(AUv3Demo_Kernel* _Nonnull obj) noexcept;
void _AUv3Demo_Kernel_release(AUv3Demo_Kernel* _Nonnull obj) noexcept;
