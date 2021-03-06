import React, { Fragment } from 'react'
import { Message } from 'semantic-ui-react'
import { formatNumber } from './../utils/formatting.js'

export const Balance = ({user, onlyBalance = false}) => {
  return (
    <div>
      {user.ethAccounts && user.ethAccounts.length > 0
      ? user.ethAccounts.map((account, index) => (
        <Fragment key={index}>
          {!onlyBalance &&
          <div className='account-name'>
            <a className='address'
              href={`https://etherscan.io/address/${account.address}`}
              target='_blank'>{account.address}
            </a>
          </div>}
          <div className='account-balance'>
            {formatNumber(account.sanBalance, 'SAN')}
          </div>
        </Fragment>
      ))
      : <Message>You don't connect any wallet with SAN tokens</Message>}
    </div>
  )
}

export default Balance
