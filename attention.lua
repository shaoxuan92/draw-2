require 'mobdebug'.start()

require 'nn'
require 'nngraph'
require 'optim'
require 'image'
local model_utils=require 'model_utils'
local mnist = require 'mnist'

nngraph.setDebug(true)


N = 2
A = 2 
h_dec_n = 100
n_data = 5

x = nn.Identity()()
y = nn.Reshape(1,1)(x)
l = {}
for i = 1, A do 
  l[#l + 1] = nn.Copy()(y)  
end
z = nn.JoinTable(2)(l)
duplicate = nn.gModule({x}, {z})


x = nn.Identity()()
h_dec = nn.Identity()()
gx = duplicate(nn.Linear(h_dec_n, 1)(h_dec))
gx = duplicate(nn.Linear(h_dec_n, 1)(h_dec))
gy = duplicate(nn.Linear(h_dec_n, 1)(h_dec))
delta = duplicate(nn.Linear(h_dec_n, 1)(h_dec))
gamma = duplicate(nn.Linear(h_dec_n, 1)(h_dec))
sigma = duplicate(nn.Linear(h_dec_n, 1)(h_dec))
delta = nn.Exp()(delta)
gamma = nn.Exp()(gamma)
sigma = nn.Exp()(sigma)
sigma = nn.Power(-2)(sigma)
sigma = nn.MulConstant(-1/2)(sigma)
gx = nn.AddConstant(1)(gx)
gy = nn.AddConstant(1)(gy)
gx = nn.MulConstant((A + 1) / 2)(gx)
gy = nn.MulConstant((A + 1) / 2)(gy)
delta = nn.MulConstant((math.max(A,A)-1)/(N-1))(delta)

ascending = nn.Identity()()

function genr_filters(g)
  filters = {}
  for i = 1, N do
      mu_i = nn.CAddTable()({g, nn.MulConstant(i - N/2 - 1/2)(delta)})
      mu_i = nn.MulConstant(-1)(mu_i)
      d_i = nn.CAddTable()({mu_i, ascending})
      d_i = nn.Power(2)(d_i)
      exp_i = nn.CMulTable()({d_i, sigma})
      exp_i = nn.Exp()(exp_i)
      exp_i = nn.View(n_data, 1, A)(exp_i)
      filters[#filters + 1] = exp_i
  end
  filterbank = nn.JoinTable(2)(filters)
  return filterbank
end

filterbank_x = genr_filters(gx)
filterbank_y = genr_filters(gy)
patch = nn.MM()({filterbank_x, x})
patch = nn.MM(false, true)({patch, filterbank_y})


m = nn.gModule({x, h_dec, ascending}, {patch})


ascending = torch.zeros(n_data, A)
for k = 1, n_data do
  for i = 1, A do 
      ascending[k][i] = i
  end
end






