/* ************
 *
 * Copyright (C) 2009  Yu Feng
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to 
 *
 * the Free Software Foundation, Inc., 
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Yu Feng <rainwoodman@gmail.com>
 ***/

using YAML;
/**
 * The GLib binding of libyaml.
 *
 * libyaml is used for parsing and emitting events.
 *
 */
	/**
	 * Internal class used to load the document
	 */
	internal class Yaml.Loader {
		public Loader() {}
		private void parse_with_throw(ref Parser parser, out Event event)
		throws Yaml.Exception {
			if(parser.parse(out event)) {
				return;
			}
			throw new Yaml.Exception.INTERNAL (
			"Parser encounters an error: %s at %u(%s)\n"
			+ "Error Context: '%s'",
				parser.problem,
				parser.problem_offset,
				parser.problem_mark.to_string(),
				parser.context);
		}

		private Document document;
		/**
		 * Load a YAML stream from a Parser to a Document.
		 *
		 * Alias are looked up at the very end of the stage.
		 */
		public bool load(ref Parser parser, Document document) 
		throws Yaml.Exception {
			this.document = document;
			Event event;
			/* Look for a StreamStart */
			if(!parser.stream_start_produced) {
				parse_with_throw(ref parser, out event);
				assert(event.type == EventType.STREAM_START_EVENT);
			}
			return_val_if_fail (!parser.stream_end_produced, true);

			parse_with_throw(ref parser, out event);
			/* if a StreamEnd seen, return OK */
			return_val_if_fail (event.type != EventType.STREAM_END_EVENT, true);

			/* expecting a DocumentStart otherwise */
			assert(event.type == EventType.DOCUMENT_START_EVENT);
			document.start_mark = event.start_mark;

			parse_with_throw(ref parser, out event);
			/* Load the first node. 
			 * load_node with recursively load other nodes */
			document.root = load_node(ref parser, ref event);
			
			/* expecting for a DocumentEnd */
			parse_with_throw(ref parser, out event);
			assert(event.type == EventType.DOCUMENT_END_EVENT);
			document.end_mark = event.end_mark;

			/* resolve the aliases */
			foreach(Node node in document.nodes) {
				if(!(node is Alias)) continue;
				var alias_node = node as Alias;
				alias_node.node = document.anchors.get(alias_node.anchor);
				if(alias_node != null) continue;
				throw new Yaml.Exception.LOADER (
					"Alias '%s' cannot be resolved.",
					alias_node.anchor);
			}
			return true;
		}
		/**
		 * Load a node from a YAML Event.
		 * 
		 * @return the loaded node.
		 */
		public Node load_node(ref Parser parser, ref Event last_event) 
		throws Yaml.Exception {
			switch(last_event.type) {
				case EventType.ALIAS_EVENT:
					return load_alias(ref parser, ref last_event);
				case EventType.SCALAR_EVENT:
					return load_scalar(ref parser, ref last_event);
				case EventType.SEQUENCE_START_EVENT:
					return load_sequence(ref parser, ref last_event);
				case EventType.MAPPING_START_EVENT:
					return load_mapping(ref parser, ref last_event);
				default:
					assert_not_reached();
			}
		}
		public Node? load_alias(ref Parser parser, ref Event event)
		throws Yaml.Exception {
			Alias node = Object.new (typeof (Alias), anchor: ((EventAlias) event).anchor) as Alias;

			/* Push the node to the document stack
			 * Do not register the anchor because it is an alias */
			document.nodes.add(node);

			return node;
		}
		private static string normalize_tag(string? tag, string @default) {
			if(tag == null || tag == "!") {
				return @default;
			}
			return tag;
		}
		public Node? load_scalar(ref Parser parser, ref Event event)
		throws Yaml.Exception {
			Scalar node = Object.new (typeof (Scalar),
					anchor:((EventScalar) event).anchor,
					tag: normalize_tag(((EventScalar) event).tag, DEFAULT_SCALAR_TAG),
					value: ((EventScalar) event).value,
					style: ((EventScalar) event).style,
					start_mark: event.start_mark,
					end_mark: event.end_mark) as Scalar;

			/* Push the node to the document stack
			 * and register the anchor */
			document.nodes.add(node);
			if(node.anchor != null)
				document.anchors.set(node.anchor, node);
			return node;
		}
		public Node? load_sequence(ref Parser parser, ref Event event)
		throws Yaml.Exception {
			Sequence node = Object.new (typeof (Sequence),
				style: ((EventSequenceStart) event).style,
				anchor: ((EventSequenceStart) event).anchor,
				tag: normalize_tag(((EventSequenceStart) event).tag, DEFAULT_SEQUENCE_TAG),
				start_mark: event.start_mark,
				end_mark: event.end_mark) as Sequence;

			/* Push the node to the document stack
			 * and register the anchor */
			document.nodes.add(node);
			if(node.anchor != null)
				document.anchors.set(node.anchor, node);

			/* Load the items in the sequence */
			parse_with_throw(ref parser, out event);
			while(event.type != EventType.SEQUENCE_END_EVENT) {
				Node item = load_node(ref parser, ref event);
				/* prepend is faster than append */
				node.items.add(item);
				parse_with_throw(ref parser, out event);
			}

			/* move the end mark of the mapping
			 * to the END_SEQUENCE_EVENT */
			node.end_mark = event.end_mark;
			return node;
		}
		public Node? load_mapping(ref Parser parser, ref Event event)
		throws Yaml.Exception {
			Mapping node = Object.new (typeof (Mapping),
					tag: normalize_tag(((EventMappingStart) event).tag, DEFAULT_MAPPING_TAG),
					anchor: ((EventMappingStart) event).anchor,
					style: ((EventMappingStart) event).style,
					start_mark: event.start_mark,
					end_mark: event.end_mark) as Mapping;

			/* Push the node to the document stack
			 * and register the anchor */
			document.nodes.add(node);
			if(node.anchor != null)
				document.anchors.set(node.anchor, node);

			/* Load the items in the mapping */
			parse_with_throw(ref parser, out event);
			while(event.type != EventType.MAPPING_END_EVENT) {
				Node key = load_node(ref parser, ref event);
				parse_with_throw(ref parser, out event);
				Node value = load_node(ref parser, ref event);
				node.pairs.set(key, value);
				parse_with_throw(ref parser, out event);
			}

			/* move the end mark of the mapping
			 * to the END_MAPPING_EVENT */
			node.end_mark = event.end_mark;
			return node;
		}
	}
