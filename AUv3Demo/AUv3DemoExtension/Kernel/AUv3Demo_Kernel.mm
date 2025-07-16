#include "AUv3Demo_Kernel.hpp"

void _AUv3Demo_Kernel_retain(AUv3Demo_Kernel* _Nonnull obj) noexcept
{
  obj->instrusiveReferenceCountedRetain();
}

void _AUv3Demo_Kernel_release(AUv3Demo_Kernel* _Nonnull obj) noexcept
{
  obj->instrusiveReferenceCountedRelease();
}
