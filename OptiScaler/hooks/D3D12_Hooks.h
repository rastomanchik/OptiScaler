#pragma once
#include "SysUtils.h"
#include <d3d12.h>

class D3D12Hooks
{
  private:
    inline static std::mutex hookMutex;
    inline static std::mutex agilityMutex;

  public:
    static void Hook();
    static void HookAgility(HMODULE module);
    static void HookDevice(ID3D12Device* device);
    static void Unhook();
    static void SetRootSignatureTracking(bool enable);
    static void RestoreComputeRootSignature(ID3D12GraphicsCommandList* cmdList);
    static void RestoreGraphicsRootSignature(ID3D12GraphicsCommandList* cmdList);
};
