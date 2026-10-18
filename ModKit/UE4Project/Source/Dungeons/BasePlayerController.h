#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "BasePlayerController.generated.h"

// Stub of the game's native /Script/Dungeons.BasePlayerController.
// It only exists so Blueprints can reference these properties by name; at
// runtime they resolve against the real class in the game executable.
// The module DLL is never packaged, so this class never ships.
UCLASS()
class DUNGEONS_API ABasePlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	// False disables dodging with the right stick (the game clears it while the quick-chat wheel is open).
	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	bool RightStickDodgingEnabled = true;

	UPROPERTY(EditAnywhere, BlueprintReadWrite)
	bool RightStickHasReset = true;
};
