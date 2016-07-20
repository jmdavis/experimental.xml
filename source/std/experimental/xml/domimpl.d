
module std.experimental.xml.domimpl;

import dom = std.experimental.xml.dom;
import std.typecons: rebindable;
import std.experimental.allocator;

class DOMImplementation(DOMString, Alloc): dom.DOMImplementation!DOMString
{
    static if (is(typeof(Alloc.instance)))
        private Alloc* allocator = &(Alloc.instance);
    else
        private Alloc* allocator;
    
    override
    {
        DocumentType createDocumentType(DOMString qualifiedName, DOMString publicId, DOMString systemId)
        {
            auto res = allocator.make!DocumentType();
            res._name = qualifiedName;
            res._publicId = publicId;
            res._systemId = systemId;
            return res;
        }
        Document createDocument(DOMString namespaceURI, DOMString qualifiedName, dom.DocumentType!DOMString _doctype)
        {
            auto doctype = cast(DocumentType)_doctype;
            if (_doctype && !doctype)
                throw new DOMException(dom.ExceptionCode.WRONG_DOCUMENT);
            return allocator.make!Document;
        }
        bool hasFeature(DOMString feature, DOMString version_) { return false; }
        Object getFeature(DOMString feature, DOMString version_) { return null; }
    }
    
    class DOMException: dom.DOMException
    {
        pure nothrow @nogc @safe this(dom.ExceptionCode code, string file = __FILE__, size_t line = __LINE__)
        {
            _code = code;
            super("", file, line);
        }
        override @property dom.ExceptionCode code()
        {
            return _code;
        }
        private dom.ExceptionCode _code;
    }
    abstract class Node: dom.Node!DOMString
    {
        override
        {
            @property Node parentNode() { return _parentNode; }
            @property Node previousSibling() { return _previousSibling; }
            @property Node nextSibling() { return _nextSibling; }
            @property Document ownerDocument() { return _ownerDocument; }
    
            bool isSameNode(dom.Node!DOMString other)
            {
                return this is other;
            }
    
            dom.UserData setUserData(string key, dom.UserData data, dom.UserDataHandler!DOMString handler)
            {
                userData[key] = data;
                if (handler)
                    userDataHandlers[key] = handler;
                return data;
            }
            dom.UserData getUserData(string key) const
            {
                if (key in userData)
                    return userData[key];
                return dom.UserData(null);
            }
        }
        private
        {
            dom.UserData[string] userData;
            dom.UserDataHandler!DOMString[string] userDataHandlers;
            Node _previousSibling, _nextSibling, _parentNode;
            Document _ownerDocument;
        }
        // methods specialized in NodeWithChildren
        override
        {
            @property dom.NodeList!DOMString childNodes() { return null; }
            @property Node firstChild() { return null; }
            @property Node lastChild() { return null; }
            
            Node insertBefore(dom.Node!DOMString _newChild, dom.Node!DOMString _refChild)
            {
                throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
            }
            Node replaceChild(dom.Node!DOMString newChild, dom.Node!DOMString oldChild)
            {
                throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
            }
            Node removeChild(dom.Node!DOMString oldChild)
            {
                throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
            }
            Node appendChild(dom.Node!DOMString newChild)
            {
                throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
            }
            bool hasChildNodes() const { return false; }
        }
        // methods specialized in Element
        override
        {
            @property dom.NamedNodeMap!DOMString attributes() { return null; }
            bool hasAttributes() { return false; }
        }
        // methods specialized in various subclasses
        override
        {
            @property DOMString nodeValue() { return null; }
            @property void nodeValue(DOMString) {}
            @property DOMString textContent() { return null; }
            @property void textContent(DOMString) {}
            @property DOMString baseURI() { return parentNode.baseURI; }
        }
        // methods specialized in Element and Attribute
        override
        {
            @property DOMString localName() { return null; }
            @property DOMString prefix() { return null; }
            @property void prefix(DOMString) { }
            @property DOMString namespaceURI() { return null; }
        }
        // TODO methods
        override
        {
            Node cloneNode(bool deep) { return null; }
            bool isEqualNode(dom.Node!DOMString arg) { return false; }
            void normalize() {}
            bool isSupported(DOMString feature, DOMString version_) { return false; }
            Object getFeature(DOMString feature, DOMString version_) { return null; }
            dom.DocumentPosition compareDocumentPosition(dom.Node!DOMString other) { return dom.DocumentPosition.IMPLEMENTATION_SPECIFIC; }
            DOMString lookupPrefix(DOMString namespaceURI) { return null; }
            DOMString lookupNamespaceURI(DOMString prefix) { return null; }
            bool isDefaultNamespace(DOMString namespaceURI) { return false; }
        }
        // method not required by the spec, specialized in NodeWithChildren
        bool isAncestor(Node other) { return false; }
    }
    private abstract class NodeWithChildren: Node
    {
        override
        {
            @property dom.NodeList!DOMString childNodes() { return null; }
            @property Node firstChild()
            {
                return _firstChild;
            }
            @property Node lastChild()
            {
                return _lastChild;
            }
            
            Node insertBefore(dom.Node!DOMString _newChild, dom.Node!DOMString _refChild)
            {
                auto newChild = cast(Node)_newChild;
                auto refChild = cast(Node)_refChild;
                if (!newChild || !refChild || newChild.ownerDocument !is ownerDocument)
                    throw new DOMException(dom.ExceptionCode.WRONG_DOCUMENT);
                if (this is newChild || newChild.isAncestor(this) || newChild is refChild)
                    throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
                if (refChild.parentNode !is this)
                    throw new DOMException(dom.ExceptionCode.NOT_FOUND);
                if (newChild.parentNode)
                    newChild.parentNode.removeChild(newChild);
                newChild._parentNode = this;
                if (refChild.previousSibling)
                {
                    refChild.previousSibling._nextSibling = newChild;
                    newChild._previousSibling = refChild.previousSibling;
                }
                refChild._previousSibling = newChild;
                newChild._nextSibling = refChild;
                if (firstChild is refChild)
                    _firstChild = newChild;
                return newChild;
            }
            Node replaceChild(dom.Node!DOMString _newChild, dom.Node!DOMString _oldChild)
            {
                auto newChild = cast(Node)_newChild;
                auto oldChild = cast(Node)_oldChild;
                if (!newChild || !oldChild || newChild.ownerDocument !is ownerDocument)
                    throw new DOMException(dom.ExceptionCode.WRONG_DOCUMENT);
                if (this is newChild || newChild.isAncestor(this))
                    throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
                if (oldChild.parentNode !is this)
                    throw new DOMException(dom.ExceptionCode.NOT_FOUND);
                if (newChild.parentNode !is null)
                    newChild.parentNode.removeChild(newChild);
                removeChild(oldChild);
                newChild._parentNode = this;
                if (oldChild.previousSibling)
                {
                    oldChild.previousSibling._nextSibling = newChild;
                    newChild._previousSibling = oldChild.previousSibling;
                    oldChild._previousSibling = null;
                }
                if (oldChild.nextSibling)
                {
                    oldChild.nextSibling._previousSibling = newChild;
                    newChild._nextSibling = oldChild.nextSibling;
                    oldChild._nextSibling = null;
                }
                if (oldChild is firstChild)
                    _firstChild = newChild;
                if (oldChild is lastChild)
                    _lastChild = newChild;
                return oldChild;
            }
            Node removeChild(dom.Node!DOMString _oldChild)
            {
                auto oldChild = cast(Node)_oldChild;
                if (!oldChild || oldChild.parentNode !is this)
                    throw new DOMException(dom.ExceptionCode.NOT_FOUND);

                if (oldChild is firstChild)
                    _firstChild = oldChild.nextSibling;
                else
                    oldChild.previousSibling._nextSibling = oldChild.nextSibling;

                if (oldChild is lastChild)
                    _lastChild = oldChild.previousSibling;
                else
                    oldChild.nextSibling._previousSibling = oldChild.previousSibling;

                oldChild._parentNode = null;
                return oldChild;
            }
            Node appendChild(dom.Node!DOMString _newChild)
            {
                auto newChild = cast(Node)_newChild;
                if (!newChild || newChild.ownerDocument !is ownerDocument)
                    throw new DOMException(dom.ExceptionCode.WRONG_DOCUMENT);
                if (this is newChild || newChild.isAncestor(this))
                    throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
                if (newChild.parentNode !is null)
                    newChild.parentNode.removeChild(newChild);
                newChild._parentNode = this;
                if (lastChild)
                {
                    newChild._previousSibling = lastChild;
                    lastChild._nextSibling = newChild;
                }
                else
                    _firstChild = newChild;
                _lastChild = newChild;
                return newChild;
            }
            bool hasChildNodes() const
            {
                return _firstChild !is null;
            }
            bool isAncestor(Node other)
            {
                for (auto child = rebindable(firstChild); child !is null; child = child.nextSibling)
                {
                    if (child is other)
                        return true;
                    if (child.isAncestor(other))
                        return true;
                }
                return false;
            }
            
            @property DOMString textContent()
            {
                DOMString result = [];
                for (auto child = rebindable(firstChild); child !is null; child = child.nextSibling)
                {
                    if (child.nodeType != dom.NodeType.COMMENT &&
                        child.nodeType != dom.NodeType.PROCESSING_INSTRUCTION &&
                        child.textContent)
                    {
                        result ~= child.textContent;
                    }
                }
                return result;
            }
            @property void textContent(DOMString newVal)
            {
                while (firstChild)
                    removeChild(firstChild);
                    
                _firstChild = _lastChild = ownerDocument.createTextNode(newVal);
            }
        }
        private
        {
            Node _firstChild, _lastChild;
        }
    }
    class DocumentFragment: NodeWithChildren, dom.DocumentFragment!DOMString
    {
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.DOCUMENT_FRAGMENT; }
            @property DOMString nodeName() { return "#document-fragment"; }
        }
    }
    class Document: NodeWithChildren, dom.Document!DOMString
    {
        // specific to Document
        override
        {
            @property DocumentType doctype() { return _doctype; }
            @property DOMImplementation implementation() { return this.outer; }
            @property Element documentElement() { return _root; }
            
            Element createElement(DOMString tagName) { return null; }
            Element createElementNS(DOMString namespaceURI, DOMString qualifiedName) { return null; }
            DocumentFragment createDocumentFragment()
            {
                auto res = allocator.make!DocumentFragment();
                res._ownerDocument = this;
                return res;
            }
            Text createTextNode(DOMString data)
            {
                auto res = allocator.make!Text();
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            Comment createComment(DOMString data)
            {
                auto res = allocator.make!Comment();
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            CDATASection createCDATASection(DOMString data)
            {
                auto res = allocator.make!CDATASection();
                res._data = data;
                res._ownerDocument = this;
                return res;
            }
            ProcessingInstruction createProcessingInstruction(DOMString target, DOMString data)
            {
                auto res = allocator.make!ProcessingInstruction();
                res._target = target;
                res._data = data;
                res._ownerDocument = this;
                return res;
            } 
            Attr createAttribute(DOMString name) { return null; } 
            Attr createAttributeNS(DOMString namespaceURI, DOMString qualifiedName) { return null; }
            EntityReference createEntityReference(DOMString name) { return null; }
            
            dom.NodeList!DOMString getElementsByTagName(DOMString tagname) { return null; }
            dom.NodeList!DOMString getElementsByTagNameNS(DOMString namespaceURI, DOMString localName) { return null; }
            Element getElementById(DOMString elementId) { return null; }

            Node importNode(dom.Node!DOMString importedNode, bool deep) { return null; } 
            Node adoptNode(dom.Node!DOMString source) { return null; } 

            @property DOMString inputEncoding() { return null; }
            @property DOMString xmlEncoding() { return null; }
            
            @property bool xmlStandalone() { return true; }
            @property void xmlStandalone(bool) { }

            @property DOMString xmlVersion() { return null; }
            @property void xmlVersion(DOMString) { }

            @property bool strictErrorChecking() { return false; }
            @property void strictErrorChecking(bool) { }
            
            @property DOMString documentURI() { return null; }
            @property void documentURI(DOMString) { }
            
            @property DOMConfiguration domConfig() { return _config; }
            void normalizeDocument() { }
            Node renameNode(dom.Node!DOMString n, DOMString namespaceURI, DOMString qualifiedName) { return null; } 
        }
        private
        {
            DocumentType _doctype;
            Element _root;
            DOMConfiguration _config;
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.DOCUMENT; }
            @property DOMString nodeName() { return "#document"; }
        }
    }
    abstract class CharacterData: Node, dom.CharacterData!DOMString
    {
        // specific to CharacterData
        override
        {
            @property DOMString data() { return _data; }
            @property void data(DOMString newVal) { _data = newVal; }
            @property size_t length() { return _data.length; }
            
            DOMString substringData(size_t offset, size_t count)
            {
                if (offset > length)
                    throw new DOMException(dom.ExceptionCode.INDEX_SIZE);

                import std.algorithm: min;
                return _data[offset..min(offset + count, length)];
            }
            void appendData(DOMString arg)
            {
                _data ~= arg;
            }
            void insertData(size_t offset, DOMString arg)
            {
                if (offset > length)
                    throw new DOMException(dom.ExceptionCode.INDEX_SIZE);

                _data = _data[0..offset] ~ arg ~ _data[offset..$];
            }
            void deleteData(size_t offset, size_t count)
            {
                if (offset > length)
                    throw new DOMException(dom.ExceptionCode.INDEX_SIZE);

                import std.algorithm: min;
                data = _data[0..offset] ~ _data[min(offset + count, length)..$];
            }
            void replaceData(size_t offset, size_t count, DOMString arg)
            {
                if (offset > length)
                    throw new DOMException(dom.ExceptionCode.INDEX_SIZE);

                import std.algorithm: min;
                _data = _data[0..offset] ~ arg ~ _data[min(offset + count, length)..$];
            }
        }
        // inherited from Node
        override
        {
            @property DOMString nodeValue() { return data; }
            @property void nodeValue(DOMString newVal) { data = newVal; }
        }
        private DOMString _data;
    }
    class Attr: NodeWithChildren, dom.Attr!DOMString
    {
        // specific to Attr
        override
        {
            @property DOMString name() { return _name; }
            @property bool specified() { return false; }
            @property DOMString value() { return null; } // <-- TODO
            @property void value(DOMString) {} // <-- TODO

            @property Element ownerElement() { return _ownerElement; }
            @property dom.XMLTypeInfo!DOMString schemaTypeInfo() { return null; }
            @property bool isId() { return false; }
        }
        private
        {
            DOMString _name;
            size_t _colon;
            Element _ownerElement;
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.ATTRIBUTE; }
            @property DOMString nodeName() { return _name; }
            
            @property DOMString nodeValue() { return _name; }
            @property void nodeValue(DOMString newVal) { value = newVal; }
        }
    }
    class Element: NodeWithChildren, dom.Element!DOMString
    {
        // specific to Element
        override
        {
            @property DOMString tagName() { return _tag; }
    
            DOMString getAttribute(DOMString name)
            {
                return _attrs.getNamedItem(name).value;
            }
            void setAttribute(DOMString name, DOMString value)
            {
                auto attr = ownerDocument.createAttribute(name);
                attr.value = value;
                attr._ownerElement = this;
                _attrs.setNamedItem(attr);
            }
            void removeAttribute(DOMString name)
            {
                _attrs.removeNamedItem(name);
            }
            
            Attr getAttributeNode(DOMString name)
            {
                return _attrs.getNamedItem(name);
            }
            Attr setAttributeNode(dom.Attr!DOMString newAttr) { return null; }
            Attr removeAttributeNode(dom.Attr!DOMString oldAttr) { return null; }
            
            DOMString getAttributeNS(DOMString namespaceURI, DOMString localName)
            {
                return _attrs.getNamedItemNS(namespaceURI, localName).value;
            }
            void setAttributeNS(DOMString namespaceURI, DOMString qualifiedName, DOMString value)
            {
                auto attr = ownerDocument.createAttributeNS(namespaceURI, qualifiedName);
                attr.value = value;
                attr._ownerElement = this;
                _attrs.setNamedItem(attr);
            }
            void removeAttributeNS(DOMString namespaceURI, DOMString localName)
            {
                _attrs.removeNamedItemNS(namespaceURI, localName);
            }
            
            Attr getAttributeNodeNS(DOMString namespaceURI, DOMString localName)
            {
                return _attrs.getNamedItemNS(namespaceURI, localName);
            }
            Attr setAttributeNodeNS(dom.Attr!DOMString newAttr) { return null; }
            
            bool hasAttribute(DOMString name)
            {
                return _attrs.getNamedItem(name) !is null;
            }
            bool hasAttributeNS(DOMString namespaceURI, DOMString localName)
            {
                return _attrs.getNamedItemNS(namespaceURI, localName) !is null;
            }
            
            void setIdAttribute(DOMString name, bool isId) { return; }
            void setIdAttributeNS(DOMString namespaceURI, DOMString localName, bool isId) { return; }
            void setIdAttributeNode(dom.Attr!DOMString idAttr, bool isId) { return; }
            
            dom.NodeList!DOMString getElementsByTagName(DOMString name) { return null; }
            dom.NodeList!DOMString getElementsByTagNameNS(DOMString namespaceURI, DOMString localName) { return null; }
            
            @property dom.XMLTypeInfo!DOMString schemaTypeInfo() { return null; }
        }
        private
        {
            DOMString _tag;
            size_t _colon;
            Map _attrs;
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.ELEMENT; }
            @property DOMString nodeName() { return _tag; }
            
            @property dom.NamedNodeMap!DOMString attributes() { return _attrs; }
            bool hasAttributes() { return _attrs !is null; }
            
            @property DOMString localName()
            {
                if (!_colon)
                    return null;
                return _tag[(_colon+1)..$];
            }
            @property DOMString prefix()
            {
                return _tag[0.._colon];
            }
            @property void prefix(DOMString pre)
            {
                _tag = pre ~ ':' ~ localName;
                _colon = pre.length;
            }
            @property DOMString namespaceURI() { return null; } // <-- TODO
        }
        
        class Map: dom.NamedNodeMap!DOMString
        {
            import std.typecons: Tuple;
            
            // specific to NamedNodeMap
            public override
            {
                ulong length() const
                {
                    return attrs.length;
                }
                Attr item(ulong index)
                {
                    if (index < attrs.keys.length)
                        return *(attrs.keys[index] in attrs);
                    else
                        return null;
                }

                Attr getNamedItem(DOMString name)
                {
                    return getNamedItemNS(null, name);
                }
                Attr setNamedItem(dom.Node!DOMString arg)
                {
                    return setNamedItemNS(arg);
                }
                Attr removeNamedItem(DOMString name)
                {
                    return removeNamedItemNS(null, name);
                }

                Attr getNamedItemNS(DOMString namespaceURI, DOMString localName)
                {
                    auto key = Key(namespaceURI, localName);
                    if (key in attrs)
                        return *(key in attrs);
                    else
                        return null;
                }
                Attr setNamedItemNS(dom.Node!DOMString arg)
                {
                    if (arg.ownerDocument !is this.outer.ownerDocument)
                        throw new DOMException(dom.ExceptionCode.WRONG_DOCUMENT);
                    Attr attr = cast(Attr)arg;
                    if (!attr)
                        throw new DOMException(dom.ExceptionCode.HIERARCHY_REQUEST);
                        
                    auto key = Key(attr.namespaceURI, attr.localName);
                    auto oldAttr = (key in attrs) ? *(key in attrs) : null;
                    attrs[key] = attr;
                    return oldAttr;
                }
                Attr removeNamedItemNS(DOMString namespaceURI, DOMString localName)
                {
                    auto key = Key(namespaceURI, localName);
                    if (key in attrs)
                    {
                        auto result = attrs.get(key, null);
                        attrs.remove(key);
                        return result;
                    }
                    else
                        throw new DOMException(dom.ExceptionCode.NOT_FOUND);
                }
            }
            private alias Key = Tuple!(DOMString, "namespaceURI", DOMString, "localName");
            private Attr[Key] attrs;
        }
    }
    class Text: CharacterData, dom.Text!DOMString
    {
        // specific to Text
        override
        {
            Text splitText(size_t offset)
            {
                if (offset > data.length)
                    throw new DOMException(dom.ExceptionCode.INDEX_SIZE);
                auto second = ownerDocument.createTextNode(data[offset..$]);
                data = data[0..offset];
                if (parentNode)
                {
                    if (nextSibling)
                        parentNode.insertBefore(second, nextSibling);
                    else
                        parentNode.appendChild(second);
                }
                return second;
            }
            @property bool isElementContentWhitespace() { return false; } // <-- TODO
            @property DOMString wholeText() { return data; } // <-- TODO
            @property Text replaceWholeText(DOMString newText) { return null; } // <-- TODO
        }
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.TEXT; }
            @property DOMString nodeName() { return "#text"; }
        }
    }
    class Comment: CharacterData, dom.Comment!DOMString
    {
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.COMMENT; }
            @property DOMString nodeName() { return "#comment"; }
        }
    }
    class DocumentType: Node, dom.DocumentType!DOMString
    {
        // specific to DocumentType
        override
        {
            @property DOMString name() { return _name; }
            @property dom.NamedNodeMap!DOMString entities() { return null; }
            @property dom.NamedNodeMap!DOMString notations() { return null; }
            @property DOMString publicId() { return _publicId; }
            @property DOMString systemId() { return _systemId; }
            @property DOMString internalSubset() { return _internalSubset; }
        }
        private DOMString _name, _publicId, _systemId, _internalSubset;
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.DOCUMENT_TYPE; }
            @property DOMString nodeName() { return _name; }
        }
    }
    class CDATASection: Text, dom.CDATASection!DOMString
    {
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.CDATA_SECTION; }
            @property DOMString nodeName() { return "#cdata-section"; }
        }
    }
    class ProcessingInstruction: Node, dom.ProcessingInstruction!DOMString
    {
        // specific to ProcessingInstruction
        override
        {
            @property DOMString target() { return _target; }
            @property DOMString data() { return _data; }
            @property void data(DOMString newVal) { _data = newVal; }
        }
        private DOMString _target, _data;
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.PROCESSING_INSTRUCTION; }
            @property DOMString nodeName() { return target; }
            @property DOMString nodeValue() { return _data; }
            @property void nodeValue(DOMString newVal) { _data = newVal; }
        }
    }
    class EntityReference: NodeWithChildren, dom.EntityReference!DOMString
    {
        // inherited from Node
        override
        {
            @property dom.NodeType nodeType() { return dom.NodeType.ENTITY_REFERENCE; }
            @property DOMString nodeName() { return _ent_name; }
        }
        private DOMString _ent_name;
    }
    abstract class DOMConfiguration: dom.DOMConfiguration!DOMString
    {
    }
}

unittest
{
    import std.experimental.allocator.gc_allocator;
    DOMImplementation!(string, shared(GCAllocator)) di;
    static assert(is(typeof(di).Document : dom.Node!string));
}