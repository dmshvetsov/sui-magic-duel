import { UserAccount } from '@/components/Authenticated'
import { CountdownTimer } from '@/components/CountdownTimer'
import { ButtonWithFx } from '@/components/ui/button'
import { useDuel } from '@/context/DuelContext'
import { formatMistBalance } from '@/lib/sui/coin'
import { displayName } from '@/lib/user'
import { useState } from 'react'

export function Start(props: { userAccount: UserAccount }) {
  const { duel, startDuel } = useDuel()
  const [isStarting, setIsStarting] = useState(false)

  if (!duel) {
    return (
      <div className="flex flex-col items-center justify-center p-6 bg-white rounded-lg shadow-md">
        <p className="text-lg font-semibold text-gray-700">Loading duel data...</p>
      </div>
    )
  }

  const handleStartDuel = () => {
    setIsStarting(true)
    startDuel(
      { countdownSeconds: 15 },
      {
        onSuccess: (result) => {
          console.debug('Start duel transaction result:', result)
        },
        onError: (err) => {
          console.error('Start duel transaction error:', err)
          setIsStarting(false)
        },
      }
    )
  }

  const wizard1 = duel.wizard1
  const wizard2 = duel.wizard2
  const wizard1Force = Number(duel.wizard1_force)
  const wizard2Force = Number(duel.wizard2_force)

  const isCurrentUserInDuel = props.userAccount.id === wizard1 || props.userAccount.id === wizard2
  const canStartDuel = isCurrentUserInDuel && !isStarting && duel.started_at === 0

  return (
    <div className="flex flex-col items-center justify-center p-6 bg-white rounded-lg shadow-md h-screen">
      <h2 className="text-2xl font-bold mb-6 text-center">Get ready for the Duel!</h2>

      <div className="w-full flex items-center mb-8">
        <div className="flex flex-col items-center w-1/3">
          <div className="w-16 h-16 bg-indigo-300 rounded-full flex items-center justify-center mb-2">
            <span className="text-2xl">🧙</span>
          </div>
          <p className="font-semibold">
            {props.userAccount.id === wizard1 ? 'You' : displayName(wizard1)}
          </p>
          <p className="text-sm text-gray-600">Force: {wizard1Force}</p>
        </div>

        <div className="text-xl font-bold grow text-center">VS</div>

        <div className="flex flex-col items-center w-1/3">
          <div className="w-16 h-16 bg-orange-300 rounded-full flex items-center justify-center mb-2">
            <span className="text-2xl">🧙‍♂️</span>
          </div>
          <p className="font-semibold">
            {props.userAccount.id === wizard2 ? 'You' : displayName(wizard2)}
          </p>
          <p className="text-sm text-gray-600">Force: {wizard2Force}</p>
        </div>
      </div>

      <div className="text-center mb-6">
        {duel.prize_pool !== '0' && (
          <h3 className="mb-4">Prize {formatMistBalance(duel.prize_pool)} Sui</h3>
        )}
        <p className="text-gray-700">
          The first wizard to reduce their opponent's force to zero wins!
        </p>
      </div>

      <div className="h-[80px] mt-4">
        {canStartDuel ? (
          <ButtonWithFx onClick={handleStartDuel} disabled={isStarting} isLoading={isStarting}>
            {isStarting ? 'Starting Duel...' : 'Start Duel'}
          </ButtonWithFx>
        ) : duel.started_at !== 0 && duel.started_at > Date.now() ? (
          <CountdownTimer to={duel.started_at} size="md" />
        ) : (
          <p className="text-sm text-gray-500 italic">
            {isCurrentUserInDuel
              ? 'Waiting for the duel to start...'
              : 'You are spectating this duel'}
          </p>
        )}
      </div>
    </div>
  )
}
