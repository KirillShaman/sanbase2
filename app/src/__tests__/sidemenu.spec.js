/* eslint-env jest */
import React from 'react'
import { shallow } from 'enzyme'
import toJson from 'enzyme-to-json'
import { SideMenu } from './../components/SideMenu'

describe('SideMenu container', () => {
  it('it should render correctly', () => {
    const user = {
      username: null,
      token: null
    }
    const loading = false
    const login = shallow(<SideMenu user={user} loading={loading} />)
    expect(toJson(login)).toMatchSnapshot()
  })

  it('it should show logout button', () => {
    const user = {
      username: 'user',
      token: 'asdfasdfi'
    }
    const loading = false
    const login = shallow(<SideMenu user={user} loading={loading} />)
    expect(toJson(login)).toMatchSnapshot()
  })

  it('it should show login button', () => {
    const user = {
      username: '',
      token: ''
    }
    const loading = false
    const login = shallow(<SideMenu user={user} loading={loading} />)
    expect(toJson(login)).toMatchSnapshot()
  })
})
