# Each Layer implements common functions, here are the stubs:

abstract Layer
forw(l::Layer, x; o...)=x
back(l::Layer, dy; o...)=dy
update(l::Layer)=nothing
setparam!(l::Layer,k,v)=nothing

# Net: Convenience type for an array of layers

typealias Net Array{Layer,1}
forw(n::Net, x; fx=true)=(for l in n; x=forw(l, x; fx=fx) end; x)
back(n::Net, dy)=(for i=length(n):-1:1 dy=back(n[i],dy; dx=(i>1)) end)
update(n::Net)=(for l in n; update(l); end)
setparam!(n::Net,k,v)=(for l in n; setparam!(l,k,v); end)

# The backprop algorithm

function backprop(net::Net, x, dy, loss=softmaxloss)
    y = forw(net, x) 	# y: network output
    loss(y, dy)         # dy: desired output -> gradient
    back(net, dy)       # calculate derivatives
end

# Predict implements forw with minibatches.

function predict(net::Net, x, y=nothing; batch=0)
    ninst = size(x, ndims(x))
    (batch == 0 || batch > ninst) && (batch = ninst)
    xx = yy = y = nothing
    for b = 1:batch:ninst
        e  = min(ninst, b + batch - 1)
        xx = x2b(xx, x, b:e)
        yy = forw(net, xx; fx=false)
        y  = b2y(y, yy, b:e, ninst)
    end
    free(xx)
    return y
end

# Train implements backprop with updates and minibatches.
# It runs for one epoch by default, iters can be specified to stop earlier.

function train(net::Net, x, y; batch=128, iters=0, loss=softmaxloss, shuffle=false)
    shuffle && shufflexy!(x,y)
    # xrows,ninst = size(x)
    # yrows,ycols = size(y)
    ninst = size(x, ndims(x))
    (batch == 0 || batch > ninst) && (batch = ninst)
    xx = yy = nothing
    for b = 1:batch:ninst
        e = min(ninst, b + batch - 1)
        xx = x2b(xx, x, b:e)
        yy = x2b(yy, y, b:e)
        backprop(net, xx, yy, loss)
        update(net)
        (iters > 0) && (e/batch >= iters) && break
    end
    free(xx); free(yy)
end

# function inittrain(net::Net, x, y, batch)
#     for l in net
#         isdefined(l,:w) && !isdefined(l,:pw) && (l.pw = UpdateParam())    
#         isdefined(l,:b) && !isdefined(l,:pb) && (l.pb = UpdateParam())
#     end
#     buf = XY()
#     chksize(buf, :x, net[1].w, (size(x, 1), batch))
#     chksize(buf, :y, net[end].w, (size(y, 1), batch))
#     return buf
# end

function x2b(b, x, r)
    bs = tuple(size(x)[1:end-1]..., length(r))
    if ((b == nothing) || (size(b) != bs))
        b == nothing || free(b)
        b = (usegpu ? CudaArray : Array)(eltype(x), bs)
    end
    bi = map(d->1:d, bs)
    xi = tuple(bi[1:end-1]..., r)
    copy!(b, bi, x, xi)
end

function b2y(y, b, r, n)
    ys = tuple(size(b)[1:end-1]..., n)
    (y == nothing) && (y = Array(eltype(b), ys))
    @assert size(y) == ys
    bi = map(d->1:d, size(b))
    yi = tuple(bi[1:end-1]..., r)
    copy!(y, yi, b, bi)
end

# Just a convenience type for training etc.
type XY x; y; XY()=new(); end

